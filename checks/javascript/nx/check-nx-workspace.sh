#!/usr/bin/env bash
# checks/javascript/nx/check-nx-workspace.sh
# Nx monorepo best practices: config, caching, circular deps, project boundaries
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "nx-workspace" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/nx.json" ] || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

NX=$(cat "$REPO/nx.json")

# --- Cache not configured ---
if ! echo "$NX" | grep -q '"cacheableOperations"\|"cache".*true\|"targetDefaults"'; then
  finding "nx-no-cache" "No caching configured — builds are slower than necessary"
fi

# --- No defaultProject or affected config ---
if ! echo "$NX" | grep -q '"defaultBase"\|"affected"'; then
  finding "nx-no-affected-base" "No defaultBase/affected config — 'nx affected' won't work correctly"
fi

# --- Missing project boundaries (enforce-module-boundaries) ---
if [ -f "$REPO/.eslintrc.json" ] || [ -f "$REPO/eslint.config.js" ]; then
  if ! grep -rq "enforce-module-boundaries\|@nx/enforce-module-boundaries" "$REPO/.eslintrc.json" "$REPO/eslint.config.js" 2>/dev/null; then
    finding "nx-no-boundaries" "No @nx/enforce-module-boundaries rule — circular deps between libs possible"
  fi
fi

# --- Circular dependencies between projects ---
if [ -d "$REPO/libs" ] || [ -d "$REPO/packages" ]; then
  # Check if any project.json references itself or obvious circular patterns
  CIRCULAR=$(find "$REPO/libs" "$REPO/packages" -name "project.json" 2>/dev/null | \
    xargs grep -l "implicitDependencies" 2>/dev/null | head -1)
  # Just hint — real detection needs nx graph
  if [ -d "$REPO/libs" ]; then
    LIB_COUNT=$(find "$REPO/libs" -maxdepth 1 -type d | wc -l | tr -d ' ')
    [ "$LIB_COUNT" -gt 20 ] && finding "nx-many-libs" "$LIB_COUNT libs — consider grouping into domains (libs/feature/, libs/shared/)"
  fi
fi

# --- No Nx Cloud (remote caching) ---
if ! echo "$NX" | grep -q '"nxCloudAccessToken"\|"nxCloud"\|"nxCloudId"'; then
  if [ ! -f "$REPO/nx-cloud.env" ]; then
    finding "nx-no-cloud" "No Nx Cloud configured — CI builds can't share cache across machines"
  fi
fi

# --- namedInputs not defined (cache invalidation) ---
if ! echo "$NX" | grep -q '"namedInputs"'; then
  finding "nx-no-named-inputs" "No namedInputs — cache may invalidate too broadly on file changes"
fi

# --- #2: Deep relative imports instead of path aliases ---
if [ -d "$REPO/libs" ]; then
  DEEP=$(cpm_grep -rl "\.\./\.\./\.\." "$REPO/libs/" "$REPO/apps/" 2>/dev/null | grep "\.ts$\|\.tsx$" | head -1 || true)
  [ -n "$DEEP" ] && finding "nx-deep-imports" "Deep relative imports in libs/ — use @org/ path aliases"
fi

# --- #4: Bypassing public API (importing deep into another lib) ---
if [ -d "$REPO/libs" ]; then
  # Pattern: from '../../other-lib/src/internal' instead of from '@org/other-lib'
  BYPASS=$(cpm_grep -rn "from ['\"].*libs/.*src/" "$REPO/libs/" "$REPO/apps/" 2>/dev/null | grep -v "index" | head -1 || true)
  [ -n "$BYPASS" ] && finding "nx-bypass-public-api" "Direct import into lib/src/ — use the public API (index.ts)"
fi

# --- #8: No tags in project.json ---
if [ -d "$REPO/libs" ]; then
  NO_TAGS=$(find "$REPO/libs" -name "project.json" -exec grep -L '"tags"' {} \; 2>/dev/null | head -3)
  [ -n "$NO_TAGS" ] && finding "nx-no-tags" "project.json without tags — can't enforce module boundaries"
fi

# --- #11: Targets without outputs (breaks caching) ---
TARGETS_NO_OUTPUT=$(find "$REPO" -name "project.json" -exec grep -l '"targets"' {} \; 2>/dev/null | \
  xargs grep -l '"build"\|"test"' 2>/dev/null | \
  xargs grep -L '"outputs"' 2>/dev/null | head -1 || true)
[ -n "$TARGETS_NO_OUTPUT" ] && finding "nx-no-outputs" "Build/test targets without outputs — caching won't work"

# --- #14: run-many --all in CI instead of affected ---
for ci in "$REPO/.github/workflows"/*.yml "$REPO/.gitlab-ci.yml" "$REPO/Jenkinsfile"; do
  if [ -f "$ci" ] && grep -q "run-many.*--all\|run-many.*--projects" "$ci" 2>/dev/null; then
    finding "nx-ci-no-affected" "CI uses 'run-many --all' — use 'nx affected' for faster pipelines"
    break
  fi
done

# --- #18: cd apps/ in root package.json scripts ---
if [ -f "$REPO/package.json" ]; then
  if grep -q '"cd apps/\|cd libs/\|cd packages/' "$REPO/package.json" 2>/dev/null; then
    finding "nx-manual-scripts" "Root package.json uses 'cd apps/' — use 'nx run <project>:<target>' instead"
  fi
fi

# --- #20: No CODEOWNERS ---
if [ ! -f "$REPO/CODEOWNERS" ] && [ ! -f "$REPO/.github/CODEOWNERS" ] && [ ! -f "$REPO/.gitlab/CODEOWNERS" ]; then
  LIB_COUNT=$(find "$REPO/libs" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [ "${LIB_COUNT:-0}" -gt 5 ] && finding "nx-no-codeowners" "No CODEOWNERS file — teams can accidentally break each other's libs"
fi

# --- NEW: implicitDependencies not configured ---
if ! echo "$NX" | grep -q '"implicitDependencies"'; then
  finding "nx-no-implicit-deps" "No implicitDependencies — non-TS deps won't trigger affected builds"
fi

# --- NEW: Generators not configured ---
if ! echo "$NX" | grep -q '"generators"'; then
  finding "nx-no-generators" "No generators config — code generation may be inconsistent"
fi

# --- NEW: targetDefaults not configured ---
if ! echo "$NX" | grep -q '"targetDefaults"'; then
  finding "nx-no-target-defaults" "No targetDefaults — shared build options not centralized"
fi

# --- NEW: Missing index.ts barrel in libs ---
if [ -d "$REPO/libs" ]; then
  LIB_DIRS=$(find "$REPO/libs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  for lib in $LIB_DIRS; do
    if [ ! -f "$lib/index.ts" ]; then
      finding "nx-no-barrel-export" "$(basename "$lib") has no index.ts — use barrel exports for public API"
      break
    fi
  done
fi

# --- NEW: Inconsistent library naming (no type prefix) ---
if [ -d "$REPO/libs" ]; then
  BAD_NAMES=$(find "$REPO/libs" -mindepth 1 -maxdepth 1 -type d \( -name "*utils*" -o -name "*components*" -o -name "*services*" \) 2>/dev/null | head -3 || true)
  [ -n "$BAD_NAMES" ] && finding "nx-inconsistent-naming" "Libs use inconsistent naming — prefer type prefixes (feature-*, ui-*, util-*)"
fi

# --- NEW: No generators workspace schematic ---
if [ ! -d "$REPO/tools/generators" ] && [ ! -d "$REPO/.nx" ]; then
  # Only warn if workspace has many libs
  LIB_COUNT=$(find "$REPO/libs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [ "${LIB_COUNT:-0}" -gt 10 ] && finding "nx-no-custom-generators" "No custom generators in tools/generators — consider adding workspace-specific schematics"
fi

# --- NEW: Inconsistent project naming (app vs lib prefix) ---
if [ -d "$REPO/apps" ] && [ -d "$REPO/libs" ]; then
  BAD_APP=$(find "$REPO/apps" -mindepth 1 -maxdepth 1 -type d ! -name "app-*" ! -name "*-app" 2>/dev/null | head -1 || true)
  [ -n "$BAD_APP" ] && finding "nx-inconsistent-project-names" "Apps don't follow naming convention — prefer app-* or *-app"
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ Nx workspace OK"
exit 0
