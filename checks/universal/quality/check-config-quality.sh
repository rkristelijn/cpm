#!/usr/bin/env bash
# checks/universal/quality/check-config-quality.sh
# @see ADR-129
# Validates project config files: sonar-project.properties, eslint, tsconfig, prettier
# Catches the most common misconfigurations that cause CI failures or silent issues.
set -o nounset -o pipefail

REPO="${1:-.}"
FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# =============================================
# SONAR-PROJECT.PROPERTIES
# =============================================

SONAR="$REPO/sonar-project.properties"
if [ -f "$SONAR" ]; then
  # 1. Missing projectKey
  grep -q "sonar.projectKey" "$SONAR" || error "sonar-no-projectkey" "sonar.projectKey missing — Sonar won't know which project this is"

  # 2. Missing organization
  grep -q "sonar.organization" "$SONAR" || finding "sonar-no-org" "sonar.organization missing — required for SonarCloud"

  # 3. Missing sources
  grep -q "sonar.sources" "$SONAR" || error "sonar-no-sources" "sonar.sources missing — Sonar won't scan any code"

  # 4. Coverage report path but no exclusions (common trap)
  if grep -q "sonar.coverageReportPaths\|sonar.javascript.lcov" "$SONAR"; then
    grep -q "sonar.coverage.exclusions" "$SONAR" || \
      finding "sonar-no-cov-exclusions" "Coverage report configured but no exclusions — test helpers/mocks inflate coverage"
  fi

  # 5. No test inclusions pattern
  grep -q "sonar.test.inclusions\|sonar.tests" "$SONAR" || \
    finding "sonar-no-test-pattern" "No sonar.tests or sonar.test.inclusions — Sonar can't distinguish tests from source"

  # 6. vendor/node_modules not excluded
  if ! grep -q "node_modules\|vendor" "$SONAR" 2>/dev/null; then
    finding "sonar-no-vendor-exclusion" "node_modules/vendor not in sonar.exclusions — Sonar may scan third-party code"
  fi

  # 7. Duplicated code exclusion missing for generated files
  if [ -d "$REPO/src" ] && find "$REPO/src" -name "*.generated.*" -o -name "*.gen.*" 2>/dev/null | head -1 | grep -q .; then
    grep -q "sonar.cpd.exclusions" "$SONAR" || \
      finding "sonar-no-cpd-exclusion" "Generated files exist but no sonar.cpd.exclusions — false duplication alerts"
  fi

  # 8. Missing projectVersion (can't track quality over releases)
  grep -q "sonar.projectVersion" "$SONAR" || \
    finding "sonar-no-version" "sonar.projectVersion missing — can't track new code period by version"

  # 9. sonar.sources includes test directories
  SOURCES=$(grep "sonar.sources" "$SONAR" 2>/dev/null | cut -d= -f2 || true)
  if echo "$SOURCES" | grep -q "test\|spec\|__tests__"; then
    finding "sonar-tests-in-sources" "Test directories in sonar.sources — tests counted as production code"
  fi

  # 10. Coverage path points to non-standard location without CI generating it
  COV_PATH=$(grep "sonar.coverageReportPaths\|sonar.javascript.lcov" "$SONAR" 2>/dev/null | cut -d= -f2 || true)
  if [ -n "$COV_PATH" ] && [ ! -f "$REPO/$COV_PATH" ]; then
    finding "sonar-coverage-file-missing" "Coverage report path ($COV_PATH) doesn't exist locally — verify CI generates it"
  fi
fi

# =============================================
# ESLINT CONFIG
# =============================================

# Detect eslint config (flat config or legacy)
ESLINT_FLAT="$REPO/eslint.config.mjs"
[ ! -f "$ESLINT_FLAT" ] && ESLINT_FLAT="$REPO/eslint.config.js"
[ ! -f "$ESLINT_FLAT" ] && ESLINT_FLAT="$REPO/eslint.config.ts"
ESLINT_LEGACY="$REPO/.eslintrc.json"
[ ! -f "$ESLINT_LEGACY" ] && ESLINT_LEGACY="$REPO/.eslintrc.js"
[ ! -f "$ESLINT_LEGACY" ] && ESLINT_LEGACY="$REPO/.eslintrc.yml"
[ ! -f "$ESLINT_LEGACY" ] && ESLINT_LEGACY="$REPO/.eslintrc"

HAS_ESLINT=0
if [ -f "$ESLINT_FLAT" ]; then
  HAS_ESLINT=1

  # 11. Flat config without ignores (replaces .eslintignore)
  if ! grep -q "ignores\|globalIgnores" "$ESLINT_FLAT" 2>/dev/null; then
    finding "eslint-no-ignores" "eslint.config without ignores pattern — node_modules/dist may be linted"
  fi

  # 12. No TypeScript plugin when project uses TS
  if [ -f "$REPO/tsconfig.json" ]; then
    if ! grep -q "typescript-eslint\|@typescript-eslint" "$ESLINT_FLAT" 2>/dev/null; then
      finding "eslint-no-ts-plugin" "TypeScript project without typescript-eslint in eslint config"
    fi
  fi

  # 13. Using legacy .eslintrc alongside flat config (confusing)
  if [ -f "$REPO/.eslintrc.json" ] || [ -f "$REPO/.eslintrc.js" ] || [ -f "$REPO/.eslintrc.yml" ]; then
    error "eslint-dual-config" "Both flat config and .eslintrc exist — eslint uses flat, .eslintrc is ignored"
  fi
fi

if [ -f "$ESLINT_LEGACY" ] && [ "$HAS_ESLINT" -eq 0 ]; then
  HAS_ESLINT=1

  # 14. Legacy config in ESLint 9+ project
  if [ -f "$REPO/package.json" ] && grep -q "\"eslint\".*\"[^0-8]" "$REPO/package.json" 2>/dev/null; then
    finding "eslint-legacy-config" ".eslintrc with ESLint 9+ — migrate to flat config (eslint.config.mjs)"
  fi
fi

# 15. No eslint config at all
if [ "$HAS_ESLINT" -eq 0 ] && [ -f "$REPO/package.json" ] && grep -q "eslint" "$REPO/package.json" 2>/dev/null; then
  finding "eslint-no-config" "eslint in dependencies but no config file — linting does nothing"
fi

# 16. eslint-disable without specific rule
if [ -d "$REPO/src" ]; then
  if grep -rn "eslint-disable\b" "$REPO/src" --include="*.ts" --include="*.tsx" 2>/dev/null | \
    grep -v "eslint-disable-next-line\|eslint-disable [a-z]" | head -1 | grep -q .; then
    finding "eslint-blanket-disable" "eslint-disable without specific rule — disables ALL rules, be specific"
  fi
fi

# 17. .eslintignore with patterns that should be in config
if [ -f "$REPO/.eslintignore" ] && [ -f "$ESLINT_FLAT" ]; then
  finding "eslint-ignore-with-flat" ".eslintignore not used by flat config — move patterns to ignores in config"
fi

# =============================================
# TSCONFIG ADDITIONAL CHECKS
# =============================================

TSCONFIG="$REPO/tsconfig.json"
if [ -f "$TSCONFIG" ]; then
  # 18. noUncheckedIndexedAccess not enabled (array[0] can be undefined)
  if ! grep -q "noUncheckedIndexedAccess" "$TSCONFIG" 2>/dev/null; then
    finding "tsconfig-no-unchecked-index" "noUncheckedIndexedAccess not set — array access silently typed as non-undefined"
  fi

  # 19. target too old
  if grep -q "\"target\".*\"es5\"\|\"target\".*\"ES5\"\|\"target\".*\"es6\"\|\"target\".*\"ES6\"" "$TSCONFIG" 2>/dev/null; then
    finding "tsconfig-old-target" "target es5/es6 — modern runtimes support ES2020+, update for better output"
  fi

  # 20. paths alias without baseUrl
  if grep -q "\"paths\"" "$TSCONFIG" 2>/dev/null; then
    if ! grep -q "\"baseUrl\"\|\"paths\"" "$TSCONFIG" 2>/dev/null | grep -q "baseUrl"; then
      # paths needs baseUrl in tsc (not in bundlers, but good practice)
      :
    fi
  fi

  # 21. isolatedModules not enabled (breaks with esbuild/swc/vite)
  if [ -f "$REPO/package.json" ] && grep -q "vite\|esbuild\|swc\|next" "$REPO/package.json" 2>/dev/null; then
    if ! grep -q "\"isolatedModules\".*true" "$TSCONFIG" 2>/dev/null; then
      finding "tsconfig-no-isolated" "isolatedModules not set — required for esbuild/swc/vite/Next.js transpilation"
    fi
  fi

  # 22. resolveJsonModule not enabled
  if ! grep -q "resolveJsonModule" "$TSCONFIG" 2>/dev/null; then
    finding "tsconfig-no-json-resolve" "resolveJsonModule not set — can't import .json files with type safety"
  fi

  # 23. Multiple tsconfig without project references
  TSCONFIG_COUNT=$(find "$REPO" -maxdepth 2 -name "tsconfig*.json" -not -path "*/node_modules/*" 2>/dev/null | wc -l)
  TSCONFIG_COUNT=$(echo "$TSCONFIG_COUNT" | tr -d ' ')
  if [ "${TSCONFIG_COUNT:-0}" -gt 2 ]; then
    if ! grep -q "references" "$TSCONFIG" 2>/dev/null; then
      finding "tsconfig-no-references" "$TSCONFIG_COUNT tsconfig files but no project references — builds may be inconsistent"
    fi
  fi
fi

# =============================================
# PRETTIER / FORMATTING
# =============================================

# 24. Both prettier and eslint formatting rules (conflict)
if [ -f "$REPO/package.json" ] && grep -q "prettier" "$REPO/package.json" 2>/dev/null; then
  if grep -rq "indent\|semi\|quotes\|comma-dangle" "$ESLINT_FLAT" "$ESLINT_LEGACY" 2>/dev/null; then
    finding "format-conflict" "Prettier + ESLint formatting rules — they'll fight. Use eslint-config-prettier"
  fi
fi

# 25. No formatter configured at all
if [ -f "$REPO/package.json" ]; then
  HAS_FORMATTER=0
  grep -q "prettier" "$REPO/package.json" 2>/dev/null && HAS_FORMATTER=1
  grep -q "biome" "$REPO/package.json" 2>/dev/null && HAS_FORMATTER=1
  [ -f "$REPO/.prettierrc" ] || [ -f "$REPO/.prettierrc.json" ] || [ -f "$REPO/prettier.config.js" ] && HAS_FORMATTER=1
  [ -f "$REPO/biome.json" ] && HAS_FORMATTER=1
  if [ "$HAS_FORMATTER" -eq 0 ]; then
    finding "no-formatter" "No formatter (prettier/biome) configured — inconsistent code style across team"
  fi
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  Config quality: all checks passed\n"
exit 0
