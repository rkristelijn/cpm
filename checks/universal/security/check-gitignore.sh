#!/usr/bin/env bash
# check-gitignore.sh — Validate .gitignore contains mandatory security patterns.
# @see ADR-129
#
# Mandatory patterns prevent accidental commit of:
#   - Secrets (.env, *.pem, *.key, credentials)
#   - PII config (.config/.pii, .config/.piiignore)
#   - IDE/OS junk (.DS_Store, .idea/, .vscode/)
#
# Optional enrichment:
#   If a known language/framework is detected, suggests additions from
#   https://www.toptal.com/developers/gitignore/api/<templates>
#
# Exit codes:
#   0 — All mandatory patterns present
#   1 — Missing mandatory patterns (findings emitted)
source "$(dirname "$0")/../../../lib/shell/check.sh"

GITIGNORE=".gitignore"

# --- Mandatory patterns (MUST be in every .gitignore) ---
# These prevent secrets and sensitive config from being committed.
# Format: "pattern|description"
MANDATORY_PATTERNS=(
  # Environment / secrets
  ".env|Environment variables (may contain secrets)"
  ".env.*|Environment variable overrides (.env.local, .env.production, etc.)"
  "!.env.example|Negation to allow .env.example template"

  # Private keys / certificates
  "*.pem|PEM private keys"
  "*.key|Private key files"
  "*.p12|PKCS#12 certificate bundles"
  "*.pfx|PFX certificate bundles"

  # Credential files
  "credentials.json|Service account / OAuth credential files"
  "*.keystore|Java/Android keystores"
  "serviceAccountKey.json|Firebase/GCP service account keys"

  # PII config (cpm-specific)
  ".config/.pii|PII patterns file (contains what to scan for)"
  ".config/.piiignore|PII suppression file"

  # OS / IDE (noise that may contain metadata)
  ".DS_Store|macOS Finder metadata"
  "Thumbs.db|Windows thumbnail cache"
)

# --- Patterns that satisfy the check (flexible matching) ---
# Some repos use broader patterns that already cover specifics.
# e.g. ".env*" covers both ".env" and ".env.*"
satisfies() {
  local required="$1"
  local gitignore_content="$2"

  # Special case: !.env.example is a negation pattern
  if [[ "$required" == "!.env.example" ]]; then
    echo "$gitignore_content" | grep -qE "^!\.env\.example$|^!\.env\.\*example" && return 0
    # If .env.example or .env.* is NOT ignored, we don't need the negation
    # Only require negation if .env* or .env.* IS present
    if echo "$gitignore_content" | grep -qE "^\.env\.\*$|^\.env\*$"; then
      return 1
    fi
    return 0  # no broad .env.* pattern, so negation isn't needed
  fi

  # Direct match (exact line in .gitignore)
  echo "$gitignore_content" | grep -qFx "$required" && return 0

  # Broader wildcard already covers it?
  case "$required" in
    .env)
      echo "$gitignore_content" | grep -qE "^\.env$|^\.env\*" && return 0 ;;
    .env.*)
      echo "$gitignore_content" | grep -qE "^\.env\.\*$|^\.env\*" && return 0 ;;
    *.pem)
      echo "$gitignore_content" | grep -qE "^\*\.pem$" && return 0 ;;
    *.key)
      echo "$gitignore_content" | grep -qE "^\*\.key$" && return 0 ;;
    *.p12)
      echo "$gitignore_content" | grep -qE "^\*\.p12$" && return 0 ;;
    *.pfx)
      echo "$gitignore_content" | grep -qE "^\*\.pfx$" && return 0 ;;
    *.keystore)
      echo "$gitignore_content" | grep -qE "^\*\.keystore$" && return 0 ;;
    credentials.json)
      echo "$gitignore_content" | grep -qE "^credentials\.json$|^credentials\*" && return 0 ;;
    serviceAccountKey.json)
      echo "$gitignore_content" | grep -qE "^serviceAccountKey\.json$|^serviceAccountKey\*|^\*AccountKey\*" && return 0 ;;
    .config/.pii)
      echo "$gitignore_content" | grep -qE "^\.config/\.pii$|^\.config/\*" && return 0 ;;
    .config/.piiignore)
      echo "$gitignore_content" | grep -qE "^\.config/\.piiignore$|^\.config/\*" && return 0 ;;
    .DS_Store)
      echo "$gitignore_content" | grep -qE "^\.DS_Store$|\*\.DS_Store" && return 0 ;;
    Thumbs.db)
      echo "$gitignore_content" | grep -qE "^Thumbs\.db$|^Thumbs\*" && return 0 ;;
  esac

  return 1
}

# --- Pre-checks ---
if [[ ! -f "$GITIGNORE" ]]; then
  findings_add "error" ".gitignore" "gitignore-missing" \
    "No .gitignore found — secrets may be committed" \
    "Create a .gitignore with mandatory security patterns: cpm check --fix" ""
  exit 0  # trap handles exit code
fi

# Strip comments and blank lines for matching
GITIGNORE_CONTENT=$(grep -v '^\s*#' "$GITIGNORE" | grep -v '^\s*$' || true)

# --- Check mandatory patterns ---
MISSING=()
for entry in "${MANDATORY_PATTERNS[@]}"; do
  pattern="${entry%%|*}"
  description="${entry#*|}"
  if ! satisfies "$pattern" "$GITIGNORE_CONTENT"; then
    MISSING+=("$pattern|$description")
    findings_add "error" "$GITIGNORE" "gitignore-missing-pattern" \
      "Missing mandatory pattern: $pattern ($description)" \
      "Add '$pattern' to .gitignore" ""
  fi
done

# --- Detect language/framework for toptal enrichment suggestions ---
detect_templates() {
  local templates=()

  # OS
  [[ "$(uname)" == "Darwin" ]] && templates+=("macos")
  templates+=("linux" "windows")

  # Languages / frameworks (detect by files present)
  [[ -f "package.json" ]] && templates+=("node")
  [[ -f "go.mod" ]] && templates+=("go")
  [[ -f "Cargo.toml" ]] && templates+=("rust")
  [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" ]] && templates+=("python")
  [[ -f "Gemfile" ]] && templates+=("ruby")
  [[ -f "pom.xml" || -f "build.gradle" || -f "build.gradle.kts" ]] && templates+=("java" "gradle" "maven")
  [[ -f "composer.json" ]] && templates+=("composer")
  [[ -f "*.csproj" || -f "*.sln" ]] 2>/dev/null && templates+=("csharp" "dotnetcore")
  [[ -f "pubspec.yaml" ]] && templates+=("dart")
  [[ -f "*.tf" ]] 2>/dev/null && templates+=("terraform")

  # IDEs (detect by directories)
  [[ -d ".idea" ]] && templates+=("jetbrains")
  [[ -d ".vscode" ]] && templates+=("visualstudiocode")

  # Deduplicate
  printf '%s\n' "${templates[@]}" | sort -u | paste -sd, -
}

# --- Enrichment (informational only, not blocking) ---
TEMPLATES=$(detect_templates)
if [[ -n "$TEMPLATES" ]]; then
  # Only fetch if we have network (timeout 3s) and there are missing patterns
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    SUGGESTED=$(curl -sf --max-time 3 "https://www.toptal.com/developers/gitignore/api/$TEMPLATES" 2>/dev/null || true)
    if [[ -n "$SUGGESTED" ]]; then
      # Count how many patterns from toptal are NOT in the current .gitignore
      EXTRA_COUNT=$(echo "$SUGGESTED" | grep -v '^\s*#' | grep -v '^\s*$' | while IFS= read -r line; do
        echo "$GITIGNORE_CONTENT" | grep -qFx "$line" || echo "$line"
      done | wc -l | tr -d ' ')

      if [[ "$EXTRA_COUNT" -gt 0 ]]; then
        findings_add "warning" "$GITIGNORE" "gitignore-enrichment" \
          "Detected templates: $TEMPLATES — $EXTRA_COUNT additional patterns available" \
          "Run: curl -sL 'https://www.toptal.com/developers/gitignore/api/$TEMPLATES' >> .gitignore" ""
      fi
    fi
  fi
fi

# --- Summary ---
if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo "  [gitignore] ✓ All ${#MANDATORY_PATTERNS[@]} mandatory security patterns present"
else
  echo "  [gitignore] ✗ ${#MISSING[@]}/${#MANDATORY_PATTERNS[@]} mandatory patterns missing"
  echo ""
  echo "  Quick fix — add these lines to .gitignore:"
  echo ""
  for entry in "${MISSING[@]}"; do
    pattern="${entry%%|*}"
    echo "    $pattern"
  done
  echo ""
  if [[ -n "$TEMPLATES" ]]; then
    echo "  Enrich with language-specific patterns:"
    echo "    curl -sL 'https://www.toptal.com/developers/gitignore/api/$TEMPLATES' >> .gitignore"
  fi
fi
