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

[ "$FINDINGS" -eq 0 ] && echo "  ✓ package.json OK"
exit 0
