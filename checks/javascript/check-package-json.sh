#!/usr/bin/env bash
# checks/javascript/check-package-json.sh
# @see ADR-129
# Package.json best practices: metadata, scripts, security, cross-platform
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/shell/init.sh" 2>/dev/null || true
cpm_check_enabled "js-package-json" || exit 0
set -o nounset -o pipefail

REPO="${1:-.}"
PKG="$REPO/package.json"
[ -f "$PKG" ] || exit 0

buf=$(cat "$PKG")
FINDINGS=0

finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# --- Metadata ---
echo "$buf" | grep -q '"description"' || finding "no-description" "No description — npm search and registry won't show context"
echo "$buf" | grep -q '"repository"' || finding "no-repository" "No repository field — 'npm repo' won't work"
echo "$buf" | grep -q '"engines"' || finding "no-engines" "No engines field — Node.js version not pinned"
echo "$buf" | grep -q '"license"' || finding "no-license" "No license field"
echo "$buf" | grep -q '"author"\|"contributors"' || finding "no-author" "No author or contributors field"

# --- LICENSE file ---
if [ ! -f "$REPO/LICENSE" ] && [ ! -f "$REPO/LICENSE.md" ] && [ ! -f "$REPO/LICENSE.txt" ]; then
  finding "no-license-file" "No LICENSE file — automated tools can't detect your license"
fi

# --- Insecure http:// URLs ---
if echo "$buf" | grep -qE '"(homepage|url|repository)".*http://' 2>/dev/null; then
  finding "insecure-url" "http:// URL in package.json — use https:// to prevent MITM attacks"
fi

# --- Dependencies ---
echo "$buf" | grep -qE '"\^|"~' && finding "unpinned-deps" "Dependencies use ^ or ~ — pin for reproducible builds"
echo "$buf" | grep -qE ':\s*"(latest|\*)"' && finding "latest-deps" "Dependencies set to 'latest' or '*' — extremely dangerous, pin to exact version"

# --- Dev packages in production dependencies ---
DEPS_SECTION=$(echo "$buf" | sed -n '/"dependencies"/,/}/p' | head -30)
if echo "$DEPS_SECTION" | grep -qE '"(jest|mocha|chai|vitest|webpack|rollup|vite|eslint|prettier|biome|typescript|ts-node|nodemon|concurrently|husky|lint-staged|@types/)"' 2>/dev/null; then
  finding "dev-in-prod" "Dev-only package in dependencies — move to devDependencies"
fi

# --- Extract scripts section (used by multiple checks below) ---
SCRIPTS=$(echo "$buf" | sed -n '/"scripts"/,/^  }/p')

# --- Lockfile ---
if [ ! -f "$REPO/package-lock.json" ] && [ ! -f "$REPO/pnpm-lock.yaml" ] && [ ! -f "$REPO/yarn.lock" ]; then
  finding "no-lockfile" "No lockfile — non-reproducible installs"
fi

# --- Lockfile in .gitignore (should NOT be ignored) ---
if [ -f "$REPO/.gitignore" ]; then
  if grep -q "package-lock.json\|yarn.lock\|pnpm-lock" "$REPO/.gitignore" 2>/dev/null; then
    finding "lockfile-gitignored" "Lockfile in .gitignore — causes 'works on my machine' issues in CI"
  fi
fi

# --- Publishable package: files field (whitelist what gets published) ---
if echo "$buf" | grep -q '"publishConfig"\|"main"\|"module"\|"exports"'; then
  echo "$buf" | grep -q '"files"' || finding "no-files-field" "Publishable package without 'files' field — may accidentally publish secrets/tests"
fi

# --- Scripts: essential commands ---
echo "$buf" | grep -q '"test"' || finding "no-test-script" "No test script — 'npm test' won't work"
echo "$buf" | grep -q '"build"' || finding "no-build-script" "No build script"
echo "$buf" | grep -q '"lint"' || finding "no-lint-script" "No lint script"
echo "$buf" | grep -q '"start"' || finding "no-start-script" "No start script"

# --- Scripts: quality of life ---
echo "$buf" | grep -q '"check"' || finding "no-check-script" "No 'check' script — add a local quality gate (lint + test + build)"

# --- Security: audit level ---
if echo "$buf" | grep -q '"audit"'; then
  echo "$buf" | grep -q "omit=dev\|--production" || finding "audit-includes-dev" "Audit script includes devDependencies — use --omit=dev"
fi

# --- Security: npx without version pin (supply chain risk) ---
if echo "$SCRIPTS" | grep -qE 'npx [a-z@]' 2>/dev/null; then
  UNPINNED_NPX=$(echo "$SCRIPTS" | grep -oE 'npx [a-z@][a-z0-9./_@-]*' | grep -v '@[0-9]' || true)
  if [ -n "$UNPINNED_NPX" ]; then
    finding "npx-no-version" "npx without version pin — supply chain risk. Pin: npx pkg@1.2.3"
  fi
fi

# --- Overrides present (should be temporary, document why) ---
if echo "$buf" | grep -q '"overrides"\|"resolutions"'; then
  finding "has-overrides" "overrides/resolutions present — ensure these are temporary and documented"
fi

# --- Cross-platform: detect non-portable commands ---
if [ -n "$SCRIPTS" ]; then
  # rm -rf, cp, mv without shx or cross-platform wrapper
  if echo "$SCRIPTS" | grep -qE '"[^"]*\b(rm -rf|cp |mv |mkdir -p)\b' 2>/dev/null; then
    if ! echo "$buf" | grep -q '"shx"\|"rimraf"\|"cpy-cli"\|"mkdirp"'; then
      finding "non-portable-scripts" "Shell commands in scripts without cross-platform wrapper (shx/rimraf)"
    fi
  fi
fi

# --- Environment: cross-env for env vars in scripts ---
if echo "$SCRIPTS" | grep -qE 'NODE_ENV=|PORT=|DEBUG=' 2>/dev/null; then
  if ! echo "$buf" | grep -q '"cross-env"\|"dotenv-cli"\|"env-cmd"'; then
    finding "no-cross-env" "Inline env vars in scripts without cross-env/dotenv-cli — breaks on Windows"
  fi
fi

# --- Pre/post hooks: lint-staged or similar for commit quality ---
if [ ! -f "$REPO/.husky/pre-commit" ] && [ ! -f "$REPO/.lintstagedrc.json" ] && [ ! -f "$REPO/.lintstagedrc" ]; then
  if ! echo "$buf" | grep -q '"lint-staged"\|"husky"\|"lefthook"'; then
    finding "no-commit-hooks" "No lint-staged/husky — linting not enforced on commit"
  fi
fi

# --- Commitizen or conventional commits ---
if ! echo "$buf" | grep -q '"commitizen"\|"@commitlint"\|"cz-conventional-changelog"'; then
  if [ ! -f "$REPO/commitlint.config.js" ] && [ ! -f "$REPO/.commitlintrc.json" ]; then
    finding "no-commit-convention" "No commitizen/commitlint — commit messages not standardized"
  fi
fi

# --- .nvmrc or volta for Node version pinning ---
if [ ! -f "$REPO/.nvmrc" ] && [ ! -f "$REPO/.node-version" ]; then
  if ! echo "$buf" | grep -q '"volta"'; then
    finding "no-node-version-file" "No .nvmrc or .node-version — team may use different Node versions"
  fi
fi

# --- .gitignore: node_modules ---
if [ -f "$REPO/.gitignore" ]; then
  grep -q "node_modules" "$REPO/.gitignore" || finding "gitignore-no-node-modules" ".gitignore missing node_modules — repo will bloat"
else
  finding "no-gitignore" "No .gitignore file"
fi

# --- Formatter config (prettier/biome) ---
if [ ! -f "$REPO/.prettierrc" ] && [ ! -f "$REPO/.prettierrc.json" ] && [ ! -f "$REPO/prettier.config.js" ]; then
  if [ ! -f "$REPO/biome.json" ] && [ ! -f "$REPO/biome.jsonc" ]; then
    finding "no-formatter" "No formatter config (prettier/biome) — inconsistent code style"
  fi
fi

# --- Scripts: silent failures (exit 0 regardless of error) ---
if echo "$SCRIPTS" | grep -qE '"\|\| true"\|"\|\| exit 0"\|"\|\| :' 2>/dev/null; then
  # Only warn if it's in test/build/lint (not in optional scripts)
  if echo "$SCRIPTS" | grep -E '"(test|build|lint|check)"' | grep -qE '\|\| true\|\|\| exit 0\|\|\| :' 2>/dev/null; then
    finding "silent-failure" "Critical script swallows errors (|| true) — failures will go unnoticed"
  fi
fi

# --- Scripts: @latest in generators (supply chain risk) ---
if echo "$SCRIPTS" | grep -qE 'create-react-app|create-next-app|@latest' 2>/dev/null; then
  finding "latest-generator" "@latest in script — pin generator version to avoid supply chain attacks"
fi

# =============================================
# PACKAGE.JSON SIZE & BLOAT
# =============================================

# --- package.json too large (loaded into memory by npm) ---
PKG_SIZE=$(wc -c < "$PKG" | tr -d ' ')
[ "${PKG_SIZE:-0}" -gt 10000 ] && finding "pkg-too-large" "package.json is ${PKG_SIZE} bytes — keep lean, npm loads it into memory"

# --- Too many scripts (>20 = hard to discover) ---
SCRIPT_COUNT=$(echo "$SCRIPTS" | grep -c '"' || echo 0)
SCRIPT_COUNT=$((SCRIPT_COUNT / 2))
[ "${SCRIPT_COUNT:-0}" -gt 20 ] && finding "too-many-scripts" "$SCRIPT_COUNT scripts — hard to discover, use Makefile or taskfile for complex workflows"

# --- Script values too long (>200 chars = unreadable, put in .sh file) ---
LONG_SCRIPTS=$(echo "$SCRIPTS" | grep -E '^    "[a-z]' | awk -F'"' '{if(length($4) > 200) print $2}' | head -1 || true)
[ -n "$LONG_SCRIPTS" ] && finding "script-too-long" "Script '$LONG_SCRIPTS' >200 chars — extract to scripts/*.sh file"

# =============================================
# DEPENDENCY PLACEMENT
# =============================================

# --- Framework in devDependencies (should be in dependencies) ---
DEVDEPS=$(echo "$buf" | sed -n '/"devDependencies"/,/}/p')
if echo "$DEVDEPS" | grep -qE '"(react|next|vue|angular|express|fastify|@nestjs|svelte)"' 2>/dev/null; then
  error "framework-in-dev" "Framework package in devDependencies — must be in dependencies for production"
fi

# --- Types packages in dependencies (should be devDependencies) ---
if echo "$DEPS_SECTION" | grep -qE '"@types/' 2>/dev/null; then
  finding "types-in-prod" "@types/* in dependencies — move to devDependencies (only needed at build time)"
fi

# --- Peer dependencies not satisfied ---
if echo "$buf" | grep -q '"peerDependencies"'; then
  PEERS=$(echo "$buf" | sed -n '/"peerDependencies"/,/}/p' | grep '"' | grep -oE '"[^"]+":' | tr -d '":' || true)
  for peer in $PEERS; do
    if ! echo "$buf" | grep -q "\"$peer\""; then
      finding "unmet-peer-dep" "peerDependency '$peer' not in deps or devDeps — consumers will get warnings"
      break
    fi
  done
fi

# --- Packages that should be peerDependencies (for libraries) ---
if echo "$buf" | grep -q '"main"\|"module"\|"exports"'; then
  # This is a library — react/react-dom should be peer
  if echo "$DEPS_SECTION" | grep -qE '"(react|react-dom|vue|svelte)"' 2>/dev/null; then
    finding "should-be-peer" "react/react-dom in dependencies of library — should be peerDependencies"
  fi
fi

# =============================================
# OVERRIDES & RESOLUTIONS HYGIENE
# =============================================

# --- Overrides without comment explaining why ---
if echo "$buf" | grep -q '"overrides"\|"resolutions"'; then
  # Count how many overrides
  OVERRIDE_COUNT=$(echo "$buf" | sed -n '/"overrides"\|"resolutions"/,/^  }/p' | grep -c '"' || echo 0)
  OVERRIDE_COUNT=$((OVERRIDE_COUNT / 2))
  [ "${OVERRIDE_COUNT:-0}" -gt 5 ] && finding "too-many-overrides" "$OVERRIDE_COUNT overrides — review if still needed, tech debt accumulates"

  # Check if override matches a direct dependency version (then it's stale)
  OVERRIDES=$(echo "$buf" | sed -n '/"overrides"\|"resolutions"/,/^  }/p' | grep -oE '"[^"]+": "[^"]+"' || true)
  if [ -n "$OVERRIDES" ]; then
    while IFS= read -r line; do
      PKG_NAME=$(echo "$line" | grep -oE '"[^"]+":' | head -1 | tr -d '":')
      PKG_VER=$(echo "$line" | grep -oE '": "[^"]+"' | grep -oE '[0-9][^"]*')
      # If same version exists in dependencies, override is stale
      if echo "$DEPS_SECTION" | grep -q "\"$PKG_NAME\".*\".*$PKG_VER" 2>/dev/null; then
        finding "stale-override" "Override '$PKG_NAME@$PKG_VER' matches dependency — remove override"
        break
      fi
    done <<< "$OVERRIDES"
  fi
fi

# =============================================
# MISSING METADATA (npm ecosystem features)
# =============================================

# --- No homepage (GitHub renders it, npm registry shows it) ---
echo "$buf" | grep -q '"homepage"' || finding "no-homepage" "No homepage field — GitHub/npm won't link to docs"

# --- No keywords (npm search discoverability) ---
if echo "$buf" | grep -q '"publishConfig"\|"main"\|"module"'; then
  echo "$buf" | grep -q '"keywords"' || finding "no-keywords" "Publishable package without keywords — invisible on npm search"
fi

# --- No bugs URL ---
echo "$buf" | grep -q '"bugs"' || finding "no-bugs-url" "No bugs field — 'npm bugs' won't work, issue reporting harder"

# --- Private field missing on app (prevents accidental publish) ---
if ! echo "$buf" | grep -q '"main"\|"module"\|"exports"'; then
  echo "$buf" | grep -q '"private".*true' || finding "no-private" "App without private:true — could accidentally publish to npm"
fi

# =============================================
# DEPENDENCY QUALITY
# =============================================

# --- Deprecated packages still in use ---
DEPRECATED_PKGS="request|node-uuid|nomnom|optimist|coffee-script|jade|natives|left-pad|npmconf|graceful-fs.*3\."
if echo "$buf" | grep -qE "\"($DEPRECATED_PKGS)\"" 2>/dev/null; then
  finding "deprecated-dep" "Known deprecated package in dependencies — find modern alternative"
fi

# --- Duplicate functionality (multiple packages for same thing) ---
HTTP_LIBS=0
echo "$buf" | grep -q '"axios"' && HTTP_LIBS=$((HTTP_LIBS+1))
echo "$buf" | grep -q '"node-fetch"' && HTTP_LIBS=$((HTTP_LIBS+1))
echo "$buf" | grep -q '"got"' && HTTP_LIBS=$((HTTP_LIBS+1))
echo "$buf" | grep -q '"superagent"' && HTTP_LIBS=$((HTTP_LIBS+1))
echo "$buf" | grep -q '"ky"' && HTTP_LIBS=$((HTTP_LIBS+1))
[ "$HTTP_LIBS" -gt 1 ] && finding "duplicate-http-libs" "$HTTP_LIBS HTTP client libs — pick one (or use native fetch)"

# --- Too many dependencies (>50 direct = bloated)
DEP_COUNT=$(echo "$DEPS_SECTION" | grep -c '"' || echo 0)
DEP_COUNT=$((DEP_COUNT / 2))
[ "${DEP_COUNT:-0}" -gt 50 ] && finding "too-many-deps" "$DEP_COUNT direct dependencies — review if all are needed"

# --- Exact duplicate versions in deps and devDeps ---
if [ -n "$DEPS_SECTION" ] && [ -n "$DEVDEPS" ]; then
  DUPES=$(comm -12 \
    <(echo "$DEPS_SECTION" | grep -oE '"[^"]+":' | sort) \
    <(echo "$DEVDEPS" | grep -oE '"[^"]+":' | sort) 2>/dev/null | tr -d '":' | head -3 || true)
  [ -n "$DUPES" ] && finding "duplicate-in-both" "Package in both deps and devDeps: $(echo $DUPES | tr '\n' ' ')"
fi

# =============================================
# SCRIPTS BEST PRACTICES
# =============================================

# --- No prepare script for husky setup ---
if echo "$buf" | grep -q '"husky"'; then
  echo "$SCRIPTS" | grep -q '"prepare"' || finding "husky-no-prepare" "Husky without prepare script — hooks won't install on 'npm install'"
fi

# --- preinstall/postinstall scripts (security concern) ---
if echo "$SCRIPTS" | grep -qE '"(preinstall|postinstall)"' 2>/dev/null; then
  finding "lifecycle-scripts" "preinstall/postinstall scripts — security risk, run arbitrary code on install"
fi

# --- Missing 'clean' script ---
if echo "$buf" | grep -q '"build"'; then
  echo "$SCRIPTS" | grep -q '"clean"' || finding "no-clean-script" "No 'clean' script — stale build artifacts cause hard-to-debug issues"
fi

# --- Missing 'typecheck' script (separate from build) ---
if [ -f "$REPO/tsconfig.json" ]; then
  if ! echo "$SCRIPTS" | grep -qE '"typecheck"\|"type-check"\|tsc.*--noEmit' 2>/dev/null; then
    finding "no-typecheck-script" "No typecheck script — run 'tsc --noEmit' separately for faster feedback"
  fi
fi

[ "$FINDINGS" -eq 0 ] && echo "  ✓ package.json OK"
exit 0
