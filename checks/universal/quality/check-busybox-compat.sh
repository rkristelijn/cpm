#!/usr/bin/env bash
# checks/universal/quality/check-busybox-compat.sh
# @see ADR-129
# Detect BusyBox/Alpine ash incompatibilities in shell scripts (top 10 issues)
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "busybox-compat" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"

# Find all .sh files
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

  LINE_NUM=0
  while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))

    # Skip comments
    if echo "$line" | grep -qE '^\s*#' 2>/dev/null; then
      continue
    fi

    # Rule 1: busybox-grep-include — grep --include/--exclude not in BusyBox
    if echo "$line" | grep -qE 'grep\s.*--(include|exclude)' 2>/dev/null; then
      findings_add "error" "$script:$LINE_NUM" "busybox-grep-include" \
        "grep --include/--exclude not supported in BusyBox" \
        "Use find ... | xargs grep, or pipe through grep -v for exclusions" \
        "https://boxmatrix.info/wiki/BusyBox-Commands"
    fi

    # Rule 2: busybox-grep-perl — grep -P (perl regex)
    if echo "$line" | grep -qE 'grep\s+-[a-zA-Z]*P' 2>/dev/null; then
      findings_add "error" "$script:$LINE_NUM" "busybox-grep-perl" \
        "grep -P (Perl regex) not available in BusyBox" \
        "Use grep -E (extended regex) instead" \
        ""
    fi

    # Rule 3: busybox-readarray — readarray/mapfile
    if echo "$line" | grep -qE '\b(readarray|mapfile)\b' 2>/dev/null; then
      findings_add "error" "$script:$LINE_NUM" "busybox-readarray" \
        "readarray/mapfile not available in BusyBox ash" \
        "Use 'while IFS= read -r line; do ... done < file' instead" \
        ""
    fi

    # Rule 4: busybox-declare-a — declare -A (associative arrays)
    if echo "$line" | grep -qE '\bdeclare\s+-A\b' 2>/dev/null; then
      findings_add "error" "$script:$LINE_NUM" "busybox-declare-a" \
        "declare -A (associative arrays) not available in BusyBox ash" \
        "Use temp files or positional parsing instead" \
        ""
    fi

    # Rule 5: busybox-date-gnu — date -d/--date (GNU-specific)
    if echo "$line" | grep -qE '\bdate\s+.*(-d\s|--date)' 2>/dev/null; then
      findings_add "warning" "$script:$LINE_NUM" "busybox-date-gnu" \
        "date -d/--date is GNU-specific, not portable to BusyBox" \
        "Use date +format or BusyBox-compatible date -D" \
        ""
    fi

    # Rule 6: busybox-stat-format — stat --format (GNU-specific)
    if echo "$line" | grep -qE '\bstat\s+.*--format' 2>/dev/null; then
      findings_add "warning" "$script:$LINE_NUM" "busybox-stat-format" \
        "stat --format is GNU-specific" \
        "Use stat -c (GNU) or stat -f (BSD); neither is fully portable" \
        ""
    fi

    # Rule 7: busybox-sort-version — sort -V
    if echo "$line" | grep -qE '\bsort\s+-[a-zA-Z]*V' 2>/dev/null; then
      findings_add "error" "$script:$LINE_NUM" "busybox-sort-version" \
        "sort -V (version sort) not available in BusyBox" \
        "Use sort -t. -k1,1n -k2,2n -k3,3n for version sorting" \
        ""
    fi

    # Rule 8: busybox-column-sep — column -s
    if echo "$line" | grep -qE '\bcolumn\s+-[a-zA-Z]*s' 2>/dev/null; then
      findings_add "warning" "$script:$LINE_NUM" "busybox-column-sep" \
        "column -s (custom separator) limited in BusyBox" \
        "Use awk or printf for column formatting" \
        ""
    fi

    # Rule 9: busybox-printf-q — printf %q
    if echo "$line" | grep -qE "\bprintf\s+.*%q" 2>/dev/null; then
      findings_add "error" "$script:$LINE_NUM" "busybox-printf-q" \
        "printf %q (shell quoting) not available in BusyBox" \
        "Use manual quoting or sed-based escaping" \
        ""
    fi

    # Rule 10: busybox-sed-bsd — sed -i '' (BSD style in-place edit)
    if echo "$line" | grep -qE "sed\s+-i\s+''" 2>/dev/null; then
      findings_add "warning" "$script:$LINE_NUM" "busybox-sed-bsd" \
        "sed -i '' is BSD-specific; GNU/BusyBox sed uses sed -i without ''" \
        "Use sed -i.bak for portability, or use a temp file" \
        ""
    fi

  done < "$script"
done <<< "$SCRIPTS"
