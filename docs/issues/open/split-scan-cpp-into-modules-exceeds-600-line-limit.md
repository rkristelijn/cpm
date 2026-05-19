---
title: split scan.cpp into modules (exceeds 600 line limit)
type: refactor
created: 2026-05-19T05:02:29+00:00
labels: [refactor, tech-debt]
remote:
---

## What

Split `src/scan.cpp` (1021 lines) into focused modules: `scan_discover.cpp` (repo discovery), `scan_checks.cpp` (file-based checks), `scan_report.cpp` (findings output).

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: cpm violates its own 600-line limit. Fixing this demonstrates dogfooding and makes the scanner easier to extend.

## Acceptance criteria

- [ ] AC1: No source file in src/ exceeds 600 lines → test: test_e2e_self_scan (check-file-size)
- [ ] AC2: `cpm scan .` produces identical output before and after split → test: test_e2e_scan_regression
- [ ] AC3: Build succeeds with no new warnings → test: make build

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

- @see ADR-129 (unified findings contract)
- @see src/scan.cpp (current monolith)
- @see cpm.toml [limits] source-lines = 600
