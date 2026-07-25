#!/usr/bin/env bash
# fix-magic-buffer-sizes.sh
# Replaces raw integer buffer size literals in C/C++ files with named constants from constants.h.
#
# Mapping logic (by size):
#   16, 32         → kept as-is (tiny semantic fields: lang, version, ext)
#   64             → kept as-is (small fixed field like section name)
#   128            → CPM_NAME_MAX  (short identifier / small string)
#   256            → CPM_NAME_MAX  (short identifier / slug / name)
#   512            → CPM_PATH_MAX  (path or command)
#   1024           → CPM_PATH_MAX  (path)
#   2048           → CPM_CMD_MAX   (command with path embedded)
#   4096           → CPM_READ_BUF  (read buffer)
#   8192           → CPM_READ_BUF  (read buffer)
#   16384          → CPM_READ_BUF  (read buffer)
#   32768          → CPM_READ_BUF  (read buffer)
#   65536          → CPM_READ_BUF_LARGE (large capture buffer)
#
# Name-based overrides (checked first):
#   *cmd*, *command*              → CPM_CMD_MAX
#   *path*, *dir*, *file*, *fpath → CPM_PATH_MAX
#   *msg*, *message*              → CPM_MSG_MAX
#   *line*, *ln*                  → CPM_LINE_MAX
#   *name*, *slug*, *repo*, *check*, *rule*, *key*, *ext*, *section* → CPM_NAME_MAX
#   *buf*, *rbuf*, *cbuf*, *gbuf*, *tbuf*, *pbuf*, *ubuf*, *cibuf*, *ncbuf* → size-based

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"

# Files still having magic numbers (from QUAL-012 scan)
FILES=(
  "$SRC_DIR/checks.cpp"
  "$SRC_DIR/checks/docs/doc_complexity.cpp"
  "$SRC_DIR/commands_test.cpp"
  "$SRC_DIR/common/runner.cpp"
  "$SRC_DIR/common/setup.cpp"
  "$SRC_DIR/common/toml.cpp"
  "$SRC_DIR/common/toml.h"
  "$SRC_DIR/io/filesystem.cpp"
  "$SRC_DIR/report/junit.cpp"
  "$SRC_DIR/runners/tool_runner.cpp"
  "$SRC_DIR/scan/scan_checks.cpp"
)

# Determine correct constant for a given variable name + size
pick_constant() {
  local varname="$1"
  local size="$2"

  # Name-based overrides first
  case "$varname" in
    *cmd*|*command*)                        echo "CPM_CMD_MAX";       return ;;
    *path*|*dir*|*fpath*|*doxy*)            echo "CPM_PATH_MAX";      return ;;
    *msg*|*message*|*text*|*wrapped*|*escaped*) echo "CPM_MSG_MAX";   return ;;
    *line*|*ln*)                            echo "CPM_LINE_MAX";       return ;;
    *name*|*slug*|*repo*|*check*|*rule*|*key*|*section*|*sev*|*installed*) echo "CPM_NAME_MAX"; return ;;
  esac

  # Size-based fallback
  case "$size" in
    128|256)  echo "CPM_NAME_MAX"      ;;
    512|1024) echo "CPM_PATH_MAX"      ;;
    2048)     echo "CPM_CMD_MAX"       ;;
    4096|8192|16384|32768) echo "CPM_READ_BUF" ;;
    65536)    echo "CPM_READ_BUF_LARGE" ;;
    *)        echo ""                  ;;  # unknown — skip
  esac
}

# Sizes we want to replace (64 and below = too small, leave alone)
SIZES_TO_REPLACE=(128 256 512 1024 2048 4096 8192 16384 32768 65536)

replaced=0
skipped=0

for file in "${FILES[@]}"; do
  [[ -f "$file" ]] || continue

  # Determine include path relative to file location
  relpath=$(realpath --relative-to="$(dirname "$file")" "$SRC_DIR/common/constants.h")

  # Add include if not already present
  if ! grep -q "constants.h" "$file"; then
    # Find a good insertion point: after the first #include line
    first_include=$(grep -n "^#include" "$file" | head -1 | cut -d: -f1)
    if [[ -n "$first_include" ]]; then
      sed -i "${first_include}a #include \"${relpath}\"" "$file"
      echo "  + added #include \"${relpath}\" to $(basename "$file")"
    fi
  fi

  # Replace each magic number
  for size in "${SIZES_TO_REPLACE[@]}"; do
    # Find all variable names with this size in this file
    while IFS=: read -r lineno decl; do
      # Extract variable name: char varname[SIZE]
      varname=$(echo "$decl" | grep -oP 'char\s+\K[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\['"$size"'\])')
      [[ -z "$varname" ]] && continue

      constant=$(pick_constant "$varname" "$size")
      [[ -z "$constant" ]] && { ((skipped++)); continue; }

      # Do the replacement on that specific line
      # Use a pattern that matches char varname[SIZE] (with optional spaces around size)
      sed -i "${lineno}s/\(char\s\+${varname}\s*\[\s*\)${size}\(\s*\]\)/${constant:+\1${constant}\2}/" "$file"
      echo "  ~ $(basename "$file"):${lineno}  char ${varname}[${size}] → ${constant}"
      ((replaced++))
    done < <(grep -n "char\s\+[a-zA-Z_][a-zA-Z0-9_]*\s*\[\s*${size}\s*\]" "$file" 2>/dev/null)
  done
done

echo ""
echo "Done: ${replaced} replacements, ${skipped} skipped (no matching constant)"
