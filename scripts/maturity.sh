#!/usr/bin/env bash
# scripts/maturity.sh — Universal repo maturity assessment
# Usage: bash scripts/maturity.sh [path]
# Scores a repo on 5 levels based on presence of quality indicators
set -o nounset -o pipefail

REPO="${1:-.}"
SCORE=0
MAX=0

check() {
  local points="$1" desc="$2" condition="$3"
  MAX=$((MAX + points))
  if eval "$condition" 2>/dev/null; then
    SCORE=$((SCORE + points))
    printf "    ✓ %s\n" "$desc"
  else
    printf "    · %s\n" "$desc"
  fi
}

echo ""
echo "  ■ Maturity Assessment: $(basename "$(cd "$REPO" && pwd)")"
echo ""

# === Level 0: Exists ===
echo "  Level 0 — Basics:"
check 1 "Has source code" "[ -d '$REPO/src' ] || [ -d '$REPO/app' ] || [ -d '$REPO/lib' ] || [ -d '$REPO/templates' ] || [ -d '$REPO/packages' ]"
check 1 "Has README.md" "[ -f '$REPO/README.md' ]"
check 1 "Has .gitignore" "[ -f '$REPO/.gitignore' ]"
check 1 "Has LICENSE" "[ -f '$REPO/LICENSE' ] || [ -f '$REPO/LICENSE.md' ]"
echo ""

# === Level 1: Managed ===
echo "  Level 1 — Managed:"
check 1 "Has lockfile" "[ -f '$REPO/package-lock.json' ] || [ -f '$REPO/pnpm-lock.yaml' ] || [ -f '$REPO/yarn.lock' ] || [ -f '$REPO/Cargo.lock' ] || [ -f '$REPO/go.sum' ] || [ -f '$REPO/pom.xml' ] || [ -f '$REPO/gradle.lock' ]"
check 1 "Has linter config" "[ -f '$REPO/.eslintrc.json' ] || [ -f '$REPO/eslint.config.js' ] || [ -f '$REPO/biome.json' ] || [ -f '$REPO/.clang-tidy' ] || [ -f '$REPO/checkstyle.xml' ] || [ -f '$REPO/.shellcheckrc' ] || [ -f '$REPO/.config/.shellcheckrc' ] || [ -f '$REPO/.config/.clang-tidy' ] || find '$REPO' -name 'sonar-project.properties' -maxdepth 3 2>/dev/null | head -1 | grep -q ."
check 1 "Has formatter config" "[ -f '$REPO/.prettierrc' ] || [ -f '$REPO/.prettierrc.json' ] || [ -f '$REPO/biome.json' ] || [ -f '$REPO/.editorconfig' ] || [ -f '$REPO/.clang-format' ] || [ -f '$REPO/.config/.clang-format' ] || [ -f '$REPO/.config/.editorconfig' ]"
check 1 "Has test script/config" "grep -q 'test' '$REPO/package.json' 2>/dev/null || [ -f '$REPO/jest.config.js' ] || [ -f '$REPO/vitest.config.ts' ] || grep -q '^test:' '$REPO/Makefile' 2>/dev/null || find '$REPO' -name '*Test.java' -maxdepth 5 2>/dev/null | head -1 | grep -q ."
check 1 "Has CI/CD pipeline" "[ -d '$REPO/.github/workflows' ] || find '$REPO' -name '.gitlab-ci.yml' -maxdepth 3 2>/dev/null | head -1 | grep -q . || [ -f '$REPO/Jenkinsfile' ]"
check 1 "Runtime version pinned" "[ -f '$REPO/.nvmrc' ] || [ -f '$REPO/.node-version' ] || [ -f '$REPO/.python-version' ] || [ -f '$REPO/rust-toolchain.toml' ] || [ -f '$REPO/flake.nix' ] || [ -f '$REPO/.sdkmanrc' ] || [ -f '$REPO/.java-version' ]"
echo ""

# === Level 2: Defined ===
echo "  Level 2 — Defined:"
check 2 "Has test files" "find '$REPO' -name '*.test.*' -o -name '*.spec.*' -o -name '*_test.*' 2>/dev/null | grep -v node_modules | head -1 | grep -q ."
check 2 "Has CHANGELOG" "[ -f '$REPO/CHANGELOG.md' ]"
check 2 "Has conventional commits" "[ -f '$REPO/commitlint.config.js' ] || [ -f '$REPO/.commitlintrc.json' ] || grep -q 'commitizen\|commitlint\|standard-version\|semantic-release' '$REPO/package.json' 2>/dev/null"
check 2 "Has docs/ folder" "[ -d '$REPO/docs' ]"
check 1 "Has CONTRIBUTING.md" "[ -f '$REPO/CONTRIBUTING.md' ]"
check 1 "Has .env.example" "[ -f '$REPO/.env.example' ] || [ -f '$REPO/.env.local.example' ]"
echo ""

# === Level 3: Measured ===
echo "  Level 3 — Measured:"
check 2 "Has coverage config" "grep -qr 'coverage\|coverageThreshold\|--coverage' '$REPO/package.json' '$REPO/jest.config.js' '$REPO/vitest.config.ts' 2>/dev/null"
check 2 "Has E2E tests" "[ -d '$REPO/cypress' ] || [ -d '$REPO/e2e' ] || [ -f '$REPO/playwright.config.ts' ]"
check 2 "Has security scanning" "grep -qr 'audit\|snyk\|gitleaks\|semgrep\|trivy' '$REPO/package.json' '$REPO/.github' 2>/dev/null"
check 1 "Has monitoring/APM" "grep -qr 'sentry\|datadog\|newrelic\|opentelemetry' '$REPO/package.json' '$REPO/src' 2>/dev/null"
check 1 "Has pre-commit hooks" "[ -d '$REPO/.husky' ] || grep -q 'husky\|lint-staged\|lefthook' '$REPO/package.json' 2>/dev/null"
echo ""

# === Level 4: Optimized ===
echo "  Level 4 — Optimized:"
check 2 "Has architecture docs (ADRs)" "[ -d '$REPO/docs/adrs' ] || [ -d '$REPO/docs/adr' ] || find '$REPO/docs' -name 'adr-*' 2>/dev/null | head -1 | grep -q ."
check 2 "Has API documentation" "grep -qr 'swagger\|openapi\|typedoc\|compodoc' '$REPO/package.json' 2>/dev/null || [ -f '$REPO/openapi.yaml' ]"
check 1 "Has feature flags" "grep -qr 'launchdarkly\|unleash\|featureFlag\|FEATURE_' '$REPO/package.json' '$REPO/src' 2>/dev/null"
check 1 "Has CODEOWNERS" "[ -f '$REPO/CODEOWNERS' ] || [ -f '$REPO/.github/CODEOWNERS' ]"
check 1 "Has SLA/SLO defined" "grep -qri 'sla\|slo\|error.budget\|availability' '$REPO/docs' 2>/dev/null"
echo ""

# === Score ===
PCT=$((SCORE * 100 / MAX))
if [ "$PCT" -ge 80 ]; then
  LEVEL="4 (Optimized)"
elif [ "$PCT" -ge 60 ]; then
  LEVEL="3 (Measured)"
elif [ "$PCT" -ge 40 ]; then
  LEVEL="2 (Defined)"
elif [ "$PCT" -ge 20 ]; then
  LEVEL="1 (Managed)"
else
  LEVEL="0 (Initial)"
fi

echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  Score: %d/%d (%d%%) — Level %s\n" "$SCORE" "$MAX" "$PCT" "$LEVEL"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
