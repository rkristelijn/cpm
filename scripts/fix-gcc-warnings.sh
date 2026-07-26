#!/usr/bin/env bash
# scripts/fix-gcc-warnings.sh — Zero warnings fix (ADR-160)
# Idempotent. Run with --verify to confirm zero warnings after.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# ═══════════════════════════════════════════════════════════════════════════════
# 1. CPM_DISCARD macro in compat.h
# ═══════════════════════════════════════════════════════════════════════════════
if ! grep -q 'CPM_DISCARD' src/common/compat.h; then
  cat >> src/common/compat.h <<'EOF'

/**
 * Suppress GCC -Wunused-result for fire-and-forget calls.
 * @see ADR-160
 */
#ifdef __GNUC__
#define CPM_DISCARD(expr) do { __typeof__(expr) _r_ __attribute__((unused)) = (expr); (void)_r_; } while(0)
#else
#define CPM_DISCARD(expr) (void)(expr)
#endif
EOF
  echo "  ✓ CPM_DISCARD macro"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 2. Ensure compat.h + constants.h are included everywhere needed
# ═══════════════════════════════════════════════════════════════════════════════
ensure_include() {
  local file="$1" inc="$2"
  if ! grep -qF "$inc" "$file"; then
    # Add after the last #include block
    local n; n=$(grep -n '^#include' "$file" | tail -1 | cut -d: -f1)
    sed -i "${n}a\\${inc}" "$file"
  fi
}

for f in src/main.cpp src/commands/commands.cpp src/commands/cmd_ops.cpp src/scan/scan_checks.cpp; do
  ensure_include "$f" '#include "../common/constants.h"'
done
# main.cpp uses a different relative path
sed -i 's|#include "../common/constants.h"|#include "common/constants.h"|' src/main.cpp
ensure_include src/common/runner.cpp '#include "compat.h"'
ensure_include src/common/runner.cpp '#include "constants.h"'
ensure_include src/common/toml.cpp '#include "constants.h"'
echo "  ✓ includes"

# ═══════════════════════════════════════════════════════════════════════════════
# 3. Wrap ALL system()/readlink()/pipe() calls that aren't already wrapped
#    Generic: works on any call shape (variable, literal, multi-line)
# ═══════════════════════════════════════════════════════════════════════════════
wrap_unused_result() {
  local file="$1"
  # Perl multi-line: find function calls that are statements (not in return/if/=)
  # and wrap them with CPM_DISCARD(...)
  perl -0777 -i -pe '
    # Match: leading whitespace + (system|readlink|pipe) + balanced parens + ;
    # But NOT already inside CPM_DISCARD and NOT preceded by "return " or "= "
    s/^([ \t]+)(?<!CPM_DISCARD\()(?<!return )((?:system|readlink|pipe)\s*\((?:[^()]*|\((?:[^()]*|\([^()]*\))*\))*\))\s*;/\1CPM_DISCARD(\2);/gm;
  ' "$file"
}

for f in src/main.cpp src/commands/commands.cpp src/commands/cmd_ops.cpp src/common/runner.cpp; do
  wrap_unused_result "$f"
done
echo "  ✓ CPM_DISCARD wrapping"

# ═══════════════════════════════════════════════════════════════════════════════
# 4. Buffer resizes — replace magic numbers with constants
#    Pattern: char NAME[N] where N causes format-truncation
# ═══════════════════════════════════════════════════════════════════════════════
# main.cpp: all path/cmd buffers
sed -i -E 's/char bin_path\[512\]/char bin_path[CPM_PATH_MAX]/' src/main.cpp
sed -i -E 's/char bin_dir[0-9]*\[512\]/char bin_dir[CPM_PATH_MAX]/g' src/main.cpp
sed -i -E 's/char cmd_buf\[512\]/char cmd_buf[CPM_CMD_MAX]/g' src/main.cpp
sed -i -E 's/char cmd_buf\[1024\]/char cmd_buf[CPM_CMD_MAX]/g' src/main.cpp
# Fix the numbered variants (bin_dir2, bin_dir3) that sed clobbered
sed -i -E 's/char bin_dir\[CPM_PATH_MAX\] = "",/char cmd_buf[CPM_CMD_MAX], bin_dir3[CPM_PATH_MAX] = "";/' src/main.cpp
# Simpler: just do targeted replacements on the known patterns
perl -i -pe 's/char cmd_buf\[512\], bin_dir3\[512\]/char cmd_buf[CPM_CMD_MAX], bin_dir3[CPM_PATH_MAX]/' src/main.cpp
perl -i -pe 's/char cmd_buf\[512\], bin_dir2\[512\]/char cmd_buf[CPM_CMD_MAX], bin_dir2[CPM_PATH_MAX]/' src/main.cpp

# commands.cpp: cwd + name
sed -i -E 's/char cwd\[512\]/char cwd[CPM_PATH_MAX]/' src/commands/commands.cpp
sed -i -E 's/char name\[128\] = ""/char name[CPM_PATH_MAX] = ""/' src/commands/commands.cpp

# scan_checks.cpp: msg buffer at the churn finding
sed -i -E 's/char msg\[256\];/char msg[CPM_MSG_MAX];/' src/scan/scan_checks.cpp

echo "  ✓ buffer resizes"

# ═══════════════════════════════════════════════════════════════════════════════
# 5. Pragma block around toml parser (intentional truncation)
# ═══════════════════════════════════════════════════════════════════════════════
if ! grep -q 'diagnostic.*format-truncation' src/common/toml.cpp; then
  python3 - <<'PYEOF'
import re

with open("src/common/toml.cpp", "r") as f:
    content = f.read()

# Insert pragma push before function
marker = "int cpm_toml_parse("
idx = content.find(marker)
if idx == -1:
    exit(1)

pragma_push = (
    "/* Intentional truncation: TOML keys/sections are short; snprintf clips gracefully. */\n"
    "#pragma GCC diagnostic push\n"
    "#pragma GCC diagnostic ignored \"-Wformat-truncation\"\n"
)
content = content[:idx] + pragma_push + content[idx:]

# Find end of function (brace counting)
func_start = content.find("{", content.find(marker))
depth = 0
end = func_start
for i in range(func_start, len(content)):
    if content[i] == "{":
        depth += 1
    elif content[i] == "}":
        depth -= 1
        if depth == 0:
            end = i
            break

content = content[: end + 1] + "\n#pragma GCC diagnostic pop\n" + content[end + 1 :]

with open("src/common/toml.cpp", "w") as f:
    f.write(content)
PYEOF
  echo "  ✓ toml pragma"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 6. Verify
# ═══════════════════════════════════════════════════════════════════════════════
if [[ "${1:-}" == "--verify" ]]; then
  echo ""
  make clean >/dev/null 2>&1
  output=$(make build 2>&1)
  warnings=$(echo "$output" | grep -c 'warning:' || true)
  if [ "$warnings" -eq 0 ]; then
    echo "  ✅ Zero warnings — build clean"
  else
    echo "  ❌ $warnings warnings remain:"
    echo "$output" | grep 'warning:'
    exit 1
  fi
fi
