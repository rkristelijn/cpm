#!/usr/bin/env bash
# check-pii.sh — Detect PII (Personally Identifiable Information) in code.
# @see ADR-129
#
# Modes:
#   (default)   Full scan of source directories for PII patterns
#   --staged    Fast scan of staged git changes only (for pre-commit hooks)
#
# Pattern sources (in priority order):
#   1. $PII_FILE (env override)
#   2. $PII_VAULT/patterns.d/*.pii (central vault, default: ~/.local/share/pii)
#   3. .config/.pii (repo-local fallback — DEPRECATED, emits warning)
#
# Suppress inline: add 'cpm:ignore pii' to the line (any comment style).
# Suppress file:   add to .config/.piiignore (format: file:pattern).
#
# Output: clickable file:line references (VSCode/terminal hyperlinks).
# @see docs/checks/pii-vault.md for best practices.

source "$(dirname "$0")/../../../lib/shell/check.sh"

# Validate a Dutch BSN via the "elfproef" (11-test) checksum. A bare 9-digit
# regex matches ANY 9-digit number (timestamps, ids, build numbers), which is
# far too strict and floods the hook with false positives. A real BSN satisfies
#   (9*d1 + 8*d2 + 7*d3 + 6*d4 + 5*d5 + 4*d6 + 3*d7 + 2*d8 - 1*d9) mod 11 == 0
# Returns 0 (true) only for numbers that pass. Used to gate `bsn` findings so we
# only flag plausible real BSNs. @see https://nl.wikipedia.org/wiki/Burgerservicenummer
_is_valid_bsn() {
  local n="$1"
  [[ "$n" =~ ^[0-9]{9}$ ]] || return 1
  local sum=0 i w
  for ((i = 0; i < 8; i++)); do
    w=$((9 - i))
    sum=$((sum + w * ${n:i:1}))
  done
  sum=$((sum - ${n:8:1}))
  (( sum % 11 == 0 ))
}

# --- PII Vault resolution ---
PII_VAULT="${PII_VAULT:-$HOME/.local/share/pii}"

# Warn if a physical .pii file exists in the repo (data leak risk)
_warn_local_pii() {
  for local_pii in ".config/.pii" ".pii"; do
    if [[ -f "$local_pii" ]]; then
      local line_count
      line_count=$(grep -cvE '^\s*(#|$)' "$local_pii" 2>/dev/null || echo 0)
      if [[ "$line_count" -gt 3 ]]; then
        findings_add "warning" "$local_pii:1" "pii-local-file" \
          "PII patterns file exists in repo ($line_count patterns)" \
          "Move to central vault: $PII_VAULT/patterns.d/ — see 'cpm docs pii-vault'" \
          ""
        echo "  ⚠ [pii] WARNING: $local_pii contains $line_count PII patterns"
        echo "    PII data should NOT live inside repositories (NIST SP 800-122, ISO 27001 A.8.12)"
        echo "    Run: cpm setup-pii-vault (or move manually to $PII_VAULT/patterns.d/)"
      fi
    fi
  done
}

# Resolve PII patterns file(s)
_resolve_pii_files() {
  # 1. Explicit env var
  if [[ -n "${PII_FILE:-}" && -f "$PII_FILE" ]]; then
    echo "$PII_FILE"
    return 0
  fi

  # 2. Central vault (all .pii files in patterns.d/)
  if [[ -d "$PII_VAULT/patterns.d" ]]; then
    local found=0
    for f in "$PII_VAULT/patterns.d"/*.pii; do
      [[ -f "$f" ]] && { echo "$f"; found=1; }
    done
    [[ $found -eq 1 ]] && return 0
  fi

  # 3. Repo-local fallback (deprecated)
  for local_pii in ".config/.pii" ".pii"; do
    if [[ -f "$local_pii" ]]; then
      echo "$local_pii"
      return 0
    fi
  done

  return 1
}

# --- Staged mode (pre-commit hook) ---
if [[ "${1:-}" == "--staged" ]]; then
  STAGED_FILES="${STAGED:-$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)}"
  # Exclude binary/lock noise, and the check script itself: its PATTERN_MAP
  # regexes and inline examples would otherwise self-match (full-scan mode
  # already excludes it via --exclude=check-pii.sh).
  STAGED_FILES=$(echo "$STAGED_FILES" | grep -vE '\.(lock|min\.js|svg|png|jpg|gif)$' | grep -vE '(^|/)check-pii\.sh$')
  [[ -z "$STAGED_FILES" ]] && exit 0

  # Warn about local .pii file
  _warn_local_pii

  # Load disabled checks from config
  DISABLED=""
  for cfg in ".config/.pii-config" ".pii-config"; do
    [[ -f "$cfg" ]] && { DISABLED=$(grep -v '^#' "$cfg" | grep '^disable' | sed 's/^disable[[:space:]]*//'); break; }
  done

  # Named patterns (disable with: "disable bsn", "disable iban", etc.)
  declare -A PATTERN_MAP=(
    [bsn]='\b[0-9]{9}\b'
    [iban]='\b[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]{0,16})\b'
    [phone-nl]='\b06[0-9]{8}\b'
    [phone-intl]='\b\+31[0-9]{9}\b'
    # Dutch postcode: 4 digits + 2 letters (optional space). On its own this is
    # ambiguous (hex colour, SKU, variable); a context keyword promotes it to
    # high confidence — see KEYWORD_MAP below.
    [postcode]='\b[1-9][0-9]{3}\s?[A-Za-z]{2}\b'
  )

  # Context-keyword map: value-form + a nearby keyword = high confidence.
  # If a pattern has an entry here, a match is a WARNING by default and is
  # promoted to ERROR only when one of these keywords appears on the same line.
  # Patterns without an entry keep their default ERROR severity. This is the
  # generic "context makes detection both more precise and broader" rule, so we
  # don't hardcode confidence per type. @see docs/checks/pii-vault.md
  declare -A KEYWORD_MAP=(
    [bsn]='bsn|burgerservice|sofinummer|sofi[_-]?nr'
    [postcode]='postcode|postal[_-]?code|\badres\b|\baddress\b|\bzip\b'
  )

  PATTERNS=()
  NAMES=()
  for name in "${!PATTERN_MAP[@]}"; do
    echo "$DISABLED" | grep -qw "$name" && continue
    PATTERNS+=("${PATTERN_MAP[$name]}")
    NAMES+=("$name")
  done

  [[ ${#PATTERNS[@]} -eq 0 ]] && exit 0

  # Single git diff → extract added lines as "file:line:content", skip suppressed
  # Parse unified diff (-U0). Hunk header is: @@ -old +new @@  where $3 is the
  # "+new[,count]" token. The added-line numbering starts at `new`, so strip the
  # leading '+' and any ',count' to get the first added line, then increment per
  # '+' line. (Using split on '+' put the number in the WRONG field and caused
  # an off-by-one in the reported file:line.)
  ADDED=$(git diff --cached -U0 -- $STAGED_FILES 2>/dev/null \
    | awk '/^diff --git/{f=substr($3,3)} /^@@/{ln=$3; sub(/^\+/,"",ln); sub(/,.*/,"",ln); ln--; next} /^\+[^+]/{ln++; if ($0 !~ /cpm:ignore pii/) print f":"ln":"substr($0,2)}')

  [[ -z "$ADDED" ]] && exit 0

  found=0
  for i in "${!PATTERNS[@]}"; do
    pattern="${PATTERNS[$i]}"
    name="${NAMES[$i]}"
    while IFS= read -r hit; do
      file="${hit%%:*}"
      linenum="$(echo "$hit" | cut -d: -f2)"
      content="$(echo "$hit" | cut -d: -f3-)"
      # Generic confidence gate: some value-forms are ambiguous on their own
      # (a 9-digit number, a postcode-like token). We use two independent signals:
      #
      #   1. Validator — a value-form check that must pass (currently only BSN,
      #      via the elfproef 11-test). A bare regex matches any 9-digit number
      #      (timestamps, ids, build numbers); the checksum weeds those out.
      #      If a validated pattern has no plausible candidate, we skip it.
      #   2. Context keyword (KEYWORD_MAP) — a keyword on the same line
      #      ("bsn:", "adres:", "postcode:") means the token is almost
      #      certainly real PII → promote to ERROR. Without the keyword the
      #      match is plausible but ambiguous → WARNING.
      #
      # Patterns with neither a validator nor a keyword entry keep ERROR (they
      # are specific enough on their own, e.g. IBAN, +31 phone numbers).
      severity="error"

      # Step 1: value-form validator (extendable per pattern).
      if [[ "$name" == "bsn" ]]; then
        valid=0
        while IFS= read -r cand; do
          _is_valid_bsn "$cand" && { valid=1; break; }
        done < <(echo "$content" | grep -oE '[0-9]{9}')
        [[ "$valid" -eq 1 ]] || continue
      fi

      # Step 2: context-keyword confidence boost. If this pattern participates
      # in the keyword scheme, default to WARNING and promote to ERROR only when
      # a context keyword is present on the same line.
      keywords="${KEYWORD_MAP[$name]:-}"
      if [[ -n "$keywords" ]]; then
        if echo "$content" | grep -qiE "$keywords"; then
          severity="error"
        else
          severity="warning"
        fi
      fi

      findings_add "$severity" "$file:$linenum" "pii-$name" \
        "Pattern '$name' matched" \
        "Add 'cpm:ignore pii' to suppress, or 'disable $name' in .config/.pii-config" ""
      found=$((found + 1))
    done < <(echo "$ADDED" | grep -E "$pattern" || true)
  done

  if [[ $found -gt 0 ]]; then
    echo "   suppress: add 'cpm:ignore pii' to the line, or 'disable <name>' in .config/.pii-config"
  fi
  exit 0  # findings_finish in trap handles exit code
fi

# --- Full scan mode ---

# Warn about local .pii file
_warn_local_pii

# Resolve pattern files
PII_FILES=()
while IFS= read -r f; do
  PII_FILES+=("$f")
done < <(_resolve_pii_files)

if [[ ${#PII_FILES[@]} -eq 0 ]]; then
  echo "  [pii] No PII patterns found."
  echo "    Setup central vault: cpm setup-pii-vault"
  echo "    Or create .config/.pii with patterns (deprecated)"
  exit 0
fi

# Load ignore list (format: file:pattern — one per line)
IGNORE_FILE=".config/.piiignore"
IGNORES=()
if [[ -f "$IGNORE_FILE" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    IGNORES+=("$line")
  done <"$IGNORE_FILE"
fi

is_ignored() {
  local file="$1" pattern="$2"
  for entry in "${IGNORES[@]+"${IGNORES[@]}"}"; do
    if [[ "$entry" == "$file:$pattern" || "$entry" == "*:$pattern" || "$entry" == "$pattern" ]]; then
      return 0
    fi
  done
  return 1
}

# Read all patterns from all resolved PII files
PATTERNS=()
for pii_file in "${PII_FILES[@]}"; do
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    PATTERNS+=("$line")
  done <"$pii_file"
done

if [[ ${#PATTERNS[@]} -eq 0 ]]; then
  echo "  [pii] skip — no patterns defined in ${PII_FILES[*]}"
  exit 0
fi

echo "  [pii] Scanning for ${#PATTERNS[@]} pattern(s) from ${#PII_FILES[@]} file(s)..."

# Determine scan directories (use what exists)
SCAN_DIRS=()
for d in src/ lib/ checks/ docs/ scripts/; do
  [[ -d "$d" ]] && SCAN_DIRS+=("$d")
done

if [[ ${#SCAN_DIRS[@]} -eq 0 ]]; then
  echo "  [pii] skip — no source directories found"
  exit 0
fi

FOUND=0
IGNORED=0
for pattern in "${PATTERNS[@]}"; do
  HITS=$(grep -rln \
    --include="*.cpp" --include="*.h" --include="*.hpp" \
    --include="*.sh" --include="*.md" --include="*.toml" \
    --include="*.json" --include="*.yml" --include="*.yaml" \
    --include="*.ts" --include="*.js" --include="*.py" \
    --include="*.tf" --include="*.hcl" \
    --exclude="check-pii.sh" \
    "$pattern" "${SCAN_DIRS[@]}" 2>/dev/null || true)
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if is_ignored "$file" "$pattern"; then
      IGNORED=$((IGNORED + 1))
    else
      grep -n "$pattern" "$file" 2>/dev/null | grep -v "cpm:ignore pii" | while IFS=: read -r linenum _; do
        findings_add "error" "$file:$linenum" "pii-detected" \
          "PII pattern '$pattern' found" \
          "Add 'cpm:ignore pii' to suppress, or add to .config/.piiignore" ""
      done
      FOUND=1
    fi
  done <<<"$HITS"
done

if [[ $IGNORED -gt 0 ]]; then
  echo "  [pii] $IGNORED ignored finding(s)"
fi
