#!/usr/bin/env bash
# check-dutch.sh — Detect Dutch content in repo files.
#
# Scans text files for Dutch marker words that never appear in English.
# Useful for repos that should be English-only.
#
# Usage:
#   bash lib/cpm/checks/universal/check-dutch.sh
#
# Config (cpm.toml):
#   [[checks]]
#   name = "check-dutch"
#   command = "lib/cpm/checks/universal/check-dutch.sh"
#   triggers = ["**/*.md", "**/*.sh", "**/*.yml"]
#   severity = "warning"
#
# Ignore file: .dutch-ignore (one glob pattern per line)
#
# Exit codes:
#   0 = clean (or warnings only)
#   1 = Dutch content detected (when severity=error)

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi

source lib/shell/init.sh 2>/dev/null || {
  print_header() { echo "==> $1"; }
  print_step()   { echo "  $2 $3${4:+ $4}"; }
}

# --- Config ---
SEVERITY="${CPM_DUTCH_SEVERITY:-warning}"
SKIP_DIRS=".git|node_modules|vendor|dist|build|.cache|target|lib/cpm"
SKIP_FILES="\.png$|\.jpg$|\.jpeg$|\.gif$|\.ico$|\.pdf$|\.woff|\.ttf|\.zip$|\.tar$|\.gz$|\.bin$|\.lock$"
IGNORE_FILE=".dutch-ignore"

# --- Dutch marker words ---
# Curated: these NEVER appear as valid English words.
# Criteria: common in Dutch, zero English usage, min 3 chars.
MARKERS=(
  # Articles & pronouns
  "het" "een" "deze" "zijn" "zij" "wij" "ons" "jullie"

  # Conjunctions & prepositions
  "maar" "omdat" "voor" "naar" "tussen" "zonder"
  "tijdens" "volgens" "behalve" "vanwege" "hoewel"

  # Adverbs
  "niet" "ook" "nog" "wel" "altijd" "soms" "vaak" "nooit"
  "hier" "daar" "waarom" "wanneer" "hoeveel" "welke"

  # Verbs (uniquely Dutch conjugations)
  "moet" "heeft" "wordt" "kunnen" "willen" "moeten" "zullen"
  "maakt" "werkt" "staat" "gaat" "komt" "denk" "weet" "gebruik"

  # Nouns & adjectives
  "bijvoorbeeld" "eigenlijk" "misschien" "verschillende"
  "belangrijk" "waarschijnlijk" "beschikbaar" "bijbehorende"
  "bestaande" "handleiding" "overzicht" "instellingen"
)

# Build grep pattern
PATTERN=$(printf '%s\n' "${MARKERS[@]}" | paste -sd'|')

# --- Helpers ---
is_ignored() {
  local file="$1"
  [[ ! -f "$IGNORE_FILE" ]] && return 1
  while IFS= read -r pattern || [[ -n "$pattern" ]]; do
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    # shellcheck disable=SC2053
    if [[ "$file" == $pattern ]]; then
      return 0
    fi
  done < "$IGNORE_FILE"
  return 1
}

# --- Main ---
print_header "checking for Dutch content..."
echo ""

HITS=0
HIT_FILES=0
TOTAL_FILES=0

while IFS= read -r file; do
  # Skip binary/image files by extension
  if echo "$file" | grep -qE "$SKIP_FILES"; then
    continue
  fi

  # Skip ignored files
  if is_ignored "$file"; then
    continue
  fi

  # Skip non-text files
  if ! file -b --mime "$file" 2>/dev/null | grep -q "text/"; then
    continue
  fi

  ((TOTAL_FILES++)) || true

  # Grep for Dutch markers (word boundary, case insensitive)
  matches=$(grep -niE "\b(${PATTERN})\b" "$file" 2>/dev/null | head -5 || true)

  if [[ -n "$matches" ]]; then
    ((HIT_FILES++)) || true
    match_count=$(echo "$matches" | wc -l)
    ((HITS += match_count)) || true
    printf "  ⚠ %s (%d matches)\n" "$file" "$match_count"
    echo "$matches" | while IFS= read -r line; do
      printf "      %s\n" "$line"
    done
    echo ""
  fi
done < <(find . -type f \
  -not -path './.git/*' \
  -not -path '*/node_modules/*' \
  -not -path '*/vendor/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/.cache/*' \
  -not -path '*/target/*' \
  -not -path '*/lib/cpm/*' \
  2>/dev/null | sort)

# --- Summary ---
echo "── Summary ──"
echo ""

if [[ $HITS -eq 0 ]]; then
  printf "  ✓ All %d files are Dutch-free\n" "$TOTAL_FILES"
  exit 0
else
  printf "  ⚠ %d file(s) contain Dutch content (%d matches in %d files scanned)\n" \
    "$HIT_FILES" "$HITS" "$TOTAL_FILES"
  echo ""
  echo "  Suppress files via .dutch-ignore (one glob per line):"
  echo "    echo './docs/research/R-008-*' >> .dutch-ignore"
  echo ""

  if [[ "$SEVERITY" == "error" ]]; then
    exit 1
  fi
  exit 0
fi
