#!/usr/bin/env bash
# discover.sh — Deep repo analysis: reverse-engineer architecture, trace links, find gaps.
# Usage: cpm discover [path]
# Does NOT modify any files. Read-only analysis.
#
# Passes:
#   1. Structure: languages, frameworks, build system, entry points
#   2. Architecture: modules, dependencies, layers, patterns
#   3. Decisions: implicit ADRs (config choices, dep versions, patterns)
#   4. Traceability: existing links, coverage gaps, dead artifacts
#   5. Quality: maturity score, top issues, recommendations
set -o nounset
set -o pipefail

TARGET="${1:-.}"
cd "$TARGET"

# Colors
B='\033[1m' D='\033[2m' G='\033[32m' Y='\033[33m' R='\033[31m' N='\033[0m'

echo ""
printf "  ${B}cpm discover${N} — $(basename "$(pwd)")\n"
echo "  ═══════════════════════════════════════════"

# --- Pass 1: Structure ---
echo ""
printf "  ${B}Pass 1: Structure${N}\n"

# Languages
declare -A langs
while IFS= read -r ext; do
  [[ -z "$ext" ]] && continue
  langs[$ext]=$(( ${langs[$ext]:-0} + 1 ))
done < <(find . -type f -not -path './.git/*' -not -path './node_modules/*' -not -path './vendor/*' -not -path './dist/*' -not -path './build/*' | sed 's/.*\.//' | sort)

# Top languages
printf "  Languages: "
for ext in $(for k in "${!langs[@]}"; do echo "${langs[$k]} $k"; done | sort -rn | head -5 | awk '{print $2}'); do
  printf "%s(%d) " "$ext" "${langs[$ext]}"
done
echo ""

# Framework detection
printf "  Frameworks: "
[[ -f package.json ]] && {
  grep -qo '"react"' package.json 2>/dev/null && printf "React "
  grep -qo '"next"' package.json 2>/dev/null && printf "Next.js "
  grep -qo '"@angular' package.json 2>/dev/null && printf "Angular "
  grep -qo '"vue"' package.json 2>/dev/null && printf "Vue "
  grep -qo '"@nestjs' package.json 2>/dev/null && printf "NestJS "
  grep -qo '"express"' package.json 2>/dev/null && printf "Express "
}
[[ -f requirements.txt || -f pyproject.toml ]] && {
  grep -qi "django" requirements.txt pyproject.toml 2>/dev/null && printf "Django "
  grep -qi "flask" requirements.txt pyproject.toml 2>/dev/null && printf "Flask "
  grep -qi "fastapi" requirements.txt pyproject.toml 2>/dev/null && printf "FastAPI "
}
[[ -f pom.xml ]] && printf "Java/Maven "
[[ -f build.gradle ]] && printf "Java/Gradle "
[[ -f Cargo.toml ]] && printf "Rust "
[[ -f go.mod ]] && printf "Go "
[[ -f Gemfile ]] && printf "Ruby "
echo ""

# Build system
printf "  Build: "
[[ -f Makefile ]] && printf "Make "
[[ -f CMakeLists.txt ]] && printf "CMake "
[[ -f Dockerfile ]] && printf "Docker "
[[ -f docker-compose.yml || -f docker-compose.yaml ]] && printf "Compose "
[[ -d .github/workflows ]] && printf "GitHub-Actions "
[[ -f .gitlab-ci.yml ]] && printf "GitLab-CI "
echo ""

# Size
files=$(find . -type f -not -path './.git/*' -not -path './node_modules/*' -not -path './vendor/*' | wc -l | tr -d ' ')
printf "  Size: %s files\n" "$files"

# --- Pass 2: Architecture ---
echo ""
printf "  ${B}Pass 2: Architecture${N}\n"

# Top-level directories (modules)
printf "  Modules: "
find . -maxdepth 1 -type d -not -name '.*' -not -name node_modules -not -name vendor -not -name dist -not -name build | sed 's|./||' | sort | tr '\n' ' '
echo ""

# Entry points
printf "  Entry points: "
[[ -f src/main.ts ]] && printf "src/main.ts "
[[ -f src/index.ts ]] && printf "src/index.ts "
[[ -f src/main.cpp ]] && printf "src/main.cpp "
[[ -f src/main.py ]] && printf "src/main.py "
[[ -f app.py ]] && printf "app.py "
[[ -f main.go ]] && printf "main.go "
[[ -f src/main.rs ]] && printf "src/main.rs "
find . -maxdepth 2 -name 'index.*' -not -path './node_modules/*' 2>/dev/null | head -3 | tr '\n' ' '
echo ""

# --- Pass 3: Implicit Decisions ---
echo ""
printf "  ${B}Pass 3: Implicit Decisions (undocumented ADRs)${N}\n"

decisions=0

# Extract deps from package.json (not description/keywords)
deps=""
[[ -f package.json ]] && deps=$(sed -n '/"dependencies"\|"devDependencies"/,/}/p' package.json 2>/dev/null)

# Package type
if [[ -f package.json ]]; then
  if grep -q '"private": false\|"main":' package.json 2>/dev/null; then
    printf "  ${D}Type: NPM library/package${N}\n"
  elif grep -q '"private": true' package.json 2>/dev/null; then
    printf "  ${D}Type: Application (private)${N}\n"
  fi
fi

# DB choice (from deps only)
db=$(echo "$deps" | grep -oE '"(pg|postgres|mysql2?|mongoose|mongodb|redis|sequelize|prisma|typeorm|knex|drizzle)"' | head -1 | tr -d '"')
[[ -n "$db" ]] && { printf "  ${Y}→${N} Database: %s (no ADR)\n" "$db"; decisions=$((decisions+1)); }

# Auth
auth=$(echo "$deps" | grep -oE '"(passport|auth0|@auth/|next-auth|lucia|clerk|jsonwebtoken)"' | head -1 | tr -d '"')
[[ -n "$auth" ]] && { printf "  ${Y}→${N} Auth: %s (no ADR)\n" "$auth"; decisions=$((decisions+1)); }

# State management
state=$(echo "$deps" | grep -oE '"(redux|zustand|mobx|recoil|jotai|pinia|vuex|@ngrx)"' | head -1 | tr -d '"')
[[ -n "$state" ]] && { printf "  ${Y}→${N} State: %s (no ADR)\n" "$state"; decisions=$((decisions+1)); }

# Testing
test_fw=$(echo "$deps" | grep -oE '"(jest|vitest|mocha|cypress|playwright|@testing-library)"' | head -1 | tr -d '"')
[[ -n "$test_fw" ]] && { printf "  ${Y}→${N} Testing: %s (no ADR)\n" "$test_fw"; decisions=$((decisions+1)); }

# Styling
style=$(echo "$deps" | grep -oE '"(tailwindcss|styled-components|@emotion|sass|less)"' | head -1 | tr -d '"')
[[ -n "$style" ]] && { printf "  ${Y}→${N} Styling: %s (no ADR)\n" "$style"; decisions=$((decisions+1)); }

# Toolchain (linter, formatter, bundler, compiler)
echo ""
printf "  ${B}Toolchain:${N} "
[[ -f tsconfig.json ]] && printf "tsc "
echo "$deps" | grep -q '"eslint"' && printf "eslint "
echo "$deps" | grep -q '"tslint"' && printf "${R}tslint(deprecated!)${N} "
echo "$deps" | grep -q '"biome"' && printf "biome "
[[ -f .prettierrc || -f .prettierrc.json || -f prettier.config.js ]] && printf "prettier "
echo "$deps" | grep -q '"webpack"' && printf "webpack "
echo "$deps" | grep -q '"vite"' && printf "vite "
echo "$deps" | grep -q '"esbuild"' && printf "esbuild "
echo "$deps" | grep -q '"rollup"' && printf "rollup "
echo ""

# EOL / outdated detection
if [[ -f package.json ]]; then
  node_ver=$(grep -o '"node":.*"' package.json 2>/dev/null | grep -oE '[0-9]+' | head -1)
  [[ -n "$node_ver" && "$node_ver" -lt 18 ]] && { printf "  ${R}!${N} Node %s is EOL — upgrade to 18+\n" "$node_ver"; }
fi

printf "  ${D}%d implicit decisions found${N}\n" "$decisions"

# --- Pass 4: Traceability ---
echo ""
printf "  ${B}Pass 4: Traceability${N}\n"

# Existing traces (only @see ADR/DES/cpm references, not generic JSDoc)
traces=$(grep -rc "@see ADR-\|@see DES-\|@trace " --include='*.ts' --include='*.js' --include='*.cpp' --include='*.py' --include='*.sh' . 2>/dev/null | awk -F: '$2>0{s+=$2}END{print s+0}')
printf "  Traceability links (@see ADR/DES): %s\n" "$traces"

# ADRs
adr_count=$(find . -path '*/adr*' -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
printf "  ADRs found: %s\n" "$adr_count"

# Docs
doc_count=$(find . -name '*.md' -not -path './node_modules/*' -not -path './vendor/*' 2>/dev/null | wc -l | tr -d ' ')
printf "  Markdown docs: %s\n" "$doc_count"

# Tests
test_count=$(find . \( -name '*test*' -o -name '*spec*' \) -type f -not -path './node_modules/*' -not -path './vendor/*' 2>/dev/null | wc -l | tr -d ' ')
printf "  Test files: %s\n" "$test_count"

# Coverage estimate
src_count=$(find . -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.cpp' -o -name '*.java' \) -not -path './node_modules/*' -not -path './vendor/*' -not -name '*test*' -not -name '*spec*' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$src_count" -gt 0 ]]; then
  trace_pct=$(( (traces * 100) / src_count ))
  test_pct=$(( (test_count * 100) / src_count ))
  printf "  Traceability coverage: ~%d%% (links/source files)\n" "$trace_pct"
  printf "  Test coverage estimate: ~%d%% (test files/source files)\n" "$test_pct"
fi

# --- Pass 5: Recommendations ---
echo ""
printf "  ${B}Pass 5: Recommendations${N}\n"

[[ "$adr_count" -eq 0 ]] && printf "  ${R}!${N} No ADRs — run: cpm new adr \"initial architecture\"\n"
[[ "$test_count" -eq 0 ]] && printf "  ${R}!${N} No tests — add test framework\n"
[[ "$traces" -eq 0 || "$traces" == "" ]] && printf "  ${Y}△${N} No traceability links — add @see references to key files\n"
[[ "$decisions" -gt 0 ]] && printf "  ${Y}△${N} %d undocumented decisions — run: cpm new adr \"<decision>\"\n" "$decisions"
[[ ! -f CONTRIBUTING.md ]] && printf "  ${Y}△${N} No CONTRIBUTING.md — add for AI agents and new devs\n"
[[ ! -f cpm.toml ]] && printf "  ${Y}△${N} No cpm.toml — run: cpm init\n"

echo ""
echo "  ═══════════════════════════════════════════"
echo ""
