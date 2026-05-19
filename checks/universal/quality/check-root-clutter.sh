#!/usr/bin/env bash
# checks/universal/quality/check-root-clutter.sh
# Detect config files in root that could live in .config/ for a cleaner root
source "$(dirname "$0")/../../../lib/shell/check.sh"
cpm_check_enabled "root-clutter" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# Config files that can typically live in .config/
MOVEABLE=""
for f in .prettierrc .prettierrc.json prettier.config.js \
         .eslintrc.json .eslintrc.js eslint.config.js \
         .stylelintrc .stylelintrc.json \
         .commitlintrc.json commitlint.config.js \
         .lintstagedrc .lintstagedrc.json \
         jest.config.js jest.config.ts \
         vitest.config.ts vitest.config.js \
         .editorconfig \
         .shellcheckrc \
         .clang-format .clang-tidy \
         biome.json biome.jsonc \
         .swcrc .babelrc babel.config.js \
         tailwind.config.js tailwind.config.ts \
         postcss.config.js \
         tsconfig.json; do
  [ -f "$REPO/$f" ] && MOVEABLE="$MOVEABLE $f"
done

COUNT=$(echo "$MOVEABLE" | wc -w | tr -d ' ')
if [ "$COUNT" -gt 3 ]; then
  finding "root-clutter" "$COUNT config files in root — consider moving to .config/"
  echo "$MOVEABLE" | tr ' ' '\n' | grep -v "^$" | sed 's/^/      /' | head -8
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Root is clean"
exit 0
