---
title: unified findings contract — migrate shell checks to findings_add
type: feat
created: 2026-05-19T05:02:29+00:00
labels: [feat, architecture]
remote:
---

## What

Migrate all 40 shell checks from ad-hoc `print_error`/`print_warning` to the structured `findings_add` API. Create `lib/shell/check.sh` wrapper that eliminates boilerplate.

## Why

Shell checks produce unstructured text output. This means:

- No queryable findings database
- No JUnit XML for CI
- No trend analysis over time
- Inconsistent fields (line numbers, fix suggestions missing)

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: All checks produce identical, queryable output — enabling `cpm findings`, JUnit CI integration, and trend detection regardless of check implementation language.

## Acceptance criteria

- [ ] AC1: `lib/shell/check.sh` wrapper exists and sources init.sh + findings_init → test: test_e2e_check_wrapper
- [ ] AC2: All 41 shell checks source check.sh (0 direct print_error for findings) → test: test_e2e_findings_consistency
- [ ] AC3: `cpm findings` returns results from shell checks → test: test_e2e_findings_query
- [ ] AC4: JUnit XML generated after shell check run → test: test_e2e_junit_output
- [ ] AC5: Every finding has: check, severity, file, rule, message, fix (6 fields) → test: test_e2e_finding_fields

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

- @see ADR-129 (unified findings contract)
- @see ADR-014 (findings database JSONL format)
- @see lib/shell/findings.sh (existing API)
