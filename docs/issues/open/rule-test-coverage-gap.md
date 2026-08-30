---
title: rule test coverage — 53/875 (6%) rules have unit tests
type: debt
created: 2026-08-30T08:32:00+02:00
labels: [debt, testing, rules]
remote:
---

## What

875 `.rule` files exist, but only 53 (6%) have a matching unit test in `rules_test.cpp`. 10 additional synthetic test IDs (PAT-001, ABS-001, etc.) test engine mechanics, not specific rules.

Discovered during Phase 0 cleanup when 8 deprecated native C++ checks were removed. The native checks had tests; the replacement rules did not. Migration tests were added manually — but this gap applies to all 822 untested rules.

## Why it matters

- **False positives go undetected** — a bad regex in a rule silently matches wrong things
- **Regressions are invisible** — refactoring the rule engine could break rules without any test failing
- **Credibility gap** — R-029 flags "insufficient validation" as the main production-readiness blocker
- **Dogfooding** — cpm checks test-to-code ratio on other repos but doesn't enforce it on its own rules

## Current state

```text
Total .rule files:     875
Tested (real rule ID):  53  (6%)
Tested (synthetic):     10  (engine-level tests)
Untested:              822
```

## Options

### Option A: SonarCloud coverage integration

Run rule tests with `--coverage` and feed the report to SonarCloud. This would show which rule engine code paths are exercised but **not** which individual rules are tested — SonarCloud tracks line coverage of C++ source, not declarative .rule file coverage.

Verdict: useful for engine code, but doesn't solve the rule coverage gap.

### Option B: Meta-check script (cpm dogfooding)

Add `checks/universal/quality/check-rule-test-coverage.sh` that:

1. Extracts all rule IDs from `rules/**/*.rule`
2. Extracts all `rule.id = "..."` from `src/rules_test.cpp`
3. Reports % coverage and lists untested rules
4. Fails at a configurable threshold (start at 10%, grow to 50%)

Verdict: fast to build, catches regressions, dogfoods cpm.

### Option C: Auto-generated smoke tests

Generate a test for every .rule file that:

1. Loads the rule
2. Validates the regex compiles
3. Runs it against a synthetic match string (derived from the regex)
4. Verifies it produces at least 1 finding

Verdict: highest coverage with least manual effort. Doesn't test edge cases or false positives, but guarantees every rule at least compiles and matches something.

### Option D: Integration test with real repos

Run all 875 rules against 5-10 real-world repos (cpm-eval suite). Track false positive rate per rule. Remove rules with >50% false positive rate.

Verdict: the ultimate validation, but slow and needs infrastructure.

## Recommendation

Start with **B** (meta-check, 1 hour), then **C** (auto-smoke, 1 day). Add **A** (SonarCloud) when coverage infra is ready. Do **D** before any public release.

## References

- R-029 Phase 3: "Validate 875 rules — run on 10 real repos, measure false positive rate"
- ADR-130: test architecture
- Phase 0 cleanup: 8 deprecated checks removed, migration tests added manually
