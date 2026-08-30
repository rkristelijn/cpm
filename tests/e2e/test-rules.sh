#!/usr/bin/env bash
# E2E test: validate rule engine finds expected patterns in fixtures
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

RULE_SCAN="./build/rule-scan"
FIXTURE="tests/e2e/fixtures/rule-test"

if [[ ! -f "$RULE_SCAN" ]]; then
  echo "SKIP: build/rule-scan not found (needs RE2)"
  exit 0
fi

echo "Running rule-scan on fixtures..."
OUTPUT=$($RULE_SCAN "$FIXTURE" 2>&1 | sed 's/\x1B\[[0-9;]*m//g') || true

ERRORS=0

expect() {
  local rule="$1" desc="$2"
  if echo "$OUTPUT" | grep -q "$rule"; then
    echo "  ✓ $rule: $desc"
  else
    echo "  ✗ $rule: $desc — NOT FOUND"
    ERRORS=$((ERRORS + 1))
  fi
}

expect "SEC-010" "AWS key detection"
expect "SEC-011" "eval() detection"
expect "QUAL-011" "console.log detection"
expect "QUAL-014" "TODO marker detection"
expect "STYLE-010" ".then() detection"
expect "STYLE-011" "deep import detection"

# Accessibility rules (bad-a11y.html)
expect "A11Y-001" "HTML missing lang"
expect "A11Y-004" "viewport user-scalable=no"
expect "A11Y-008" "empty heading"
expect "A11Y-029" "click on div"
expect "A11Y-037" "anchor as button"
expect "A11Y-107" "empty link"
expect "A11Y-108" "empty button"
expect "A11Y-110" "marquee element"
expect "A11Y-111" "blink element"
expect "A11Y-112" "deprecated b element"

# Build error rules (bad-build.tsx + bad-build.ts + bad-build.vue)
expect "BUILD-003" "async useEffect"
expect "BUILD-026" "const enum export"
expect "BUILD-040" "process.exit in lib"
expect "BUILD-011" "Vue props destructure"
expect "BUILD-012" "reactive reassign"

# Secrets rules (bad-secrets.env)
expect "SECRETS-011" "GitLab PAT detection"
expect "SECRETS-019" "npm token detection"
expect "SECRETS-026" "SendGrid API key"
expect "SECRETS-039" "MongoDB URI with password"
expect "SECRETS-066" "Vault token detection"
expect "SECRETS-080" "Bearer token in code"

# AI/ML security rules (bad-ai-ml.py)
expect "AIML-001" "pickle.load detection"
expect "AIML-002" "torch.load detection"
expect "AIML-006" "yaml.load unsafe"
expect "AIML-014" "from_pretrained detection"

# Transport rules (bad-transport.sh)
expect "TRANS-002" "curl insecure"
expect "TRANS-003" "wget no-check-certificate"
expect "TRANS-007" "git ssl no verify"

# Design pattern anti-patterns (bad-patterns.ts)
# @see R-030 (Design Patterns vs Native Platform Features)
expect "PATTERN-001" "Singleton getInstance in module-based language"
expect "PATTERN-002" "DI container in framework with native DI"
expect "PATTERN-003" "Interface + single implementation pair"
expect "PATTERN-004" "Empty catch / missing error handling"
expect "PATTERN-005" "Manual Observer/EventBus in reactive framework"
expect "PATTERN-006" "External call without circuit breaker"
expect "PATTERN-007" "Repository wrapper around ORM"
expect "PATTERN-008" "Builder for simple class"
expect "PATTERN-009" "Abstract Factory with single implementation"
expect "PATTERN-010" "Strategy with single implementation"

echo ""
if [[ "$ERRORS" -eq 0 ]]; then
  echo "✅ All rule assertions passed"
else
  echo "❌ $ERRORS rule assertion(s) failed"
  exit 1
fi
