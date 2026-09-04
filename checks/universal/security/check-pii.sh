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
  STAGED_FILES=$(echo "$STAGED_FILES" | grep -vE '\.(lock|min\.js|svg|png|jpg|gif)$')
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
  )

  # Checksum/structural validators — mirror lib/no-pii.sh so both paths agree.
  # A regex match is only reported when the value actually validates, cutting
  # false positives (random 9-digit numbers, malformed IBANs, ...).
  _pii_all_same() { local s="$1" first="${1:0:1}"; [ -z "${s//$first/}" ]; }
  _pii_sequential() {
    local n="$1" asc="0123456789012345678" desc="9876543210987654321"
    case "$asc" in *"$n"*) return 0 ;; esac
    case "$desc" in *"$n"*) return 0 ;; esac
    return 1
  }
  pii_valid_bsn() {
    local n="$1"; [[ "$n" =~ ^[0-9]{9}$ ]] || return 1
    _pii_all_same "$n" && return 1; _pii_sequential "$n" && return 1
    local sum=0 i d w
    for ((i=0;i<9;i++)); do d=${n:i:1}; if ((i==8)); then w=-1; else w=$((9-i)); fi; sum=$((sum+d*w)); done
    (( sum % 11 == 0 ))
  }
  pii_valid_iban() {
    local iban="${1//[[:space:]]/}"; iban="${iban^^}"
    [[ "$iban" =~ ^[A-Z]{2}[0-9]{2}[A-Z0-9]+$ ]] || return 1
    local rearr="${iban:4}${iban:0:4}" numeric="" i ch code
    for ((i=0;i<${#rearr};i++)); do
      ch=${rearr:i:1}
      if [[ "$ch" =~ [0-9] ]]; then numeric+="$ch"; else code=$(( $(printf '%d' "'$ch") - 55 )); numeric+="$code"; fi
    done
    local rem=0 chunk
    while [ -n "$numeric" ]; do chunk="$rem${numeric:0:7}"; numeric="${numeric:7}"; rem=$(( 10#$chunk % 97 )); done
    (( rem == 1 ))
  }
  pii_check_value() {
    local name="$1" text="$2" v
    case "$name" in
      bsn)  v=$(printf '%s' "$text" | grep -oE '[0-9]{9}' | head -1); pii_valid_bsn "$v" ;;
      iban) v=$(printf '%s' "$text" | grep -oiE '[A-Z]{2}[0-9]{2}[A-Z0-9]+' | head -1); pii_valid_iban "$v" ;;
      *)    return 0 ;;
    esac
  }

  PATTERNS=()
  NAMES=()
  for name in "${!PATTERN_MAP[@]}"; do
    echo "$DISABLED" | grep -qw "$name" && continue
    PATTERNS+=("${PATTERN_MAP[$name]}")
    NAMES+=("$name")
  done

  [[ ${#PATTERNS[@]} -eq 0 ]] && exit 0

  # Single git diff → extract added lines as "file:line:content", skip suppressed
  ADDED=$(git diff --cached -U0 -- $STAGED_FILES 2>/dev/null \
    | awk '/^diff --git/{f=substr($3,3)} /^@@/{split($3,a,"+"); ln=a[1]+0; sub(/,.*/,"",ln); ln--; next} /^\+[^+]/{ln++; if ($0 !~ /cpm:ignore pii/) print f":"ln":"substr($0,2)}')

  [[ -z "$ADDED" ]] && exit 0

  found=0
  for i in "${!PATTERNS[@]}"; do
    pattern="${PATTERNS[$i]}"
    name="${NAMES[$i]}"
    while IFS= read -r hit; do
      file="${hit%%:*}"
      linenum="$(echo "$hit" | cut -d: -f2)"
      content="$(echo "$hit" | cut -d: -f3-)"
      pii_check_value "$name" "$content" || continue
      findings_add "error" "$file:$linenum" "pii-$name" \
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
