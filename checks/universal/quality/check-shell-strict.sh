#!/usr/bin/env bash
# checks/universal/quality/check-shell-strict.sh
# @see ADR-129
# Validate shell scripts have shebang, strict mode (set -e/-u/pipefail)
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "shell-strict" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Find all .sh files, excluding standard dirs
SCRIPTS=$(find "$REPO" -name '*.sh' -type f \
  -not -path "*/node_modules/*" \
  -not -path "*/vendor/*" \
  -not -path "*/.git/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -path "*/coverage/*" \
  -not -path "*/.cache/*" \
  -not -path "*/target/*" \
  -not -path "*/out/*" \
  2>/dev/null) || true

[ -z "$SCRIPTS" ] && exit 0

while IFS= read -r script; do
  [ -z "$script" ] && continue
  [ ! -f "$script" ] && continue

  # Skip files that source check.sh — cpm's own checks already get strict mode
  if head -10 "$script" | grep -q 'source.*check\.sh' 2>/dev/null; then
    continue
  fi

  FIRST_LINE=$(head -1 "$script" 2>/dev/null) || continue
  HEAD_10=$(head -10 "$script" 2>/dev/null) || continue

  # Rule 3: shell-no-shebang — No shebang at all
  if ! echo "$FIRST_LINE" | grep -qE '^#!.*(bash|sh)' 2>/dev/null; then
    findings_add "error" "$script" "shell-no-shebang" \
      "Shell script without shebang line" \
      "Add #!/usr/bin/env bash as the first line" \
      "https://www.shellcheck.net/wiki/SC2148"
    continue
  fi

  # Rule 1: shell-no-strict — No strict mode flags in first 10 lines
  HAS_ERREXIT=false
  HAS_NOUNSET=false
  HAS_PIPEFAIL=false

  echo "$HEAD_10" | grep -qE 'set -[eoux]*e|set -o errexit' 2>/dev/null && HAS_ERREXIT=true
  echo "$HEAD_10" | grep -qE 'set -[eoux]*u|set -o nounset' 2>/dev/null && HAS_NOUNSET=true
  echo "$HEAD_10" | grep -qE 'set -o pipefail' 2>/dev/null && HAS_PIPEFAIL=true

  # Also check for combined forms like set -euo pipefail
  if echo "$HEAD_10" | grep -qE 'set -[a-z]*e[a-z]*o pipefail' 2>/dev/null; then
    HAS_ERREXIT=true
    HAS_PIPEFAIL=true
  fi
  if echo "$HEAD_10" | grep -qE 'set -[a-z]*u' 2>/dev/null; then
    HAS_NOUNSET=true
  fi

  MISSING=""
  $HAS_ERREXIT || MISSING="${MISSING}errexit "
  $HAS_NOUNSET || MISSING="${MISSING}nounset "
  $HAS_PIPEFAIL || MISSING="${MISSING}pipefail "

  if [ -n "$MISSING" ]; then
    findings_add "warning" "$script" "shell-no-strict" \
      "Missing strict mode flags in first 10 lines: ${MISSING}" \
      "Add: set -o errexit -o nounset -o pipefail" \
      "https://www.shellcheck.net/wiki/SC2086"
  fi

  # Rule 2: shell-no-errexit — Missing errexit specifically (only if others are present)
  if ! $HAS_ERREXIT && ($HAS_NOUNSET || $HAS_PIPEFAIL); then
    findings_add "info" "$script" "shell-no-errexit" \
      "Script has some strict flags but missing errexit (set -e)" \
      "Add: set -o errexit" \
      ""
  fi

done <<< "$SCRIPTS"
