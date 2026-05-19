---
title: minimum quality baseline — 80% traceability, 50% test coverage
type: feat
created: 2026-05-19T09:09:00+00:00
labels: [feat, quality]
remote:
---

## What

Bring all quality metrics to a minimum acceptable level:

| Metric | Current | Target |
|--------|---------|--------|
| Traceability | 52% | 80% |
| Test coverage (files) | 8% | 50% |
| Doc coverage | 100% | 100% ✓ |
| Scan findings | 0 | 0 ✓ |

## Why

We enforce quality on others but don't meet our own standards. Dogfooding requires minimum baselines.

## Value

- Quality characteristic: Reliability + Maintainability
- Stakeholder benefit: Every file is traceable to a decision, every module has tests.

## Acceptance criteria

- [ ] AC1: `cpm trace` shows ≥80% coverage
- [ ] AC2: test files / source files ≥50%
- [ ] AC3: `cpm check` enforces these thresholds (fails if below)

## Done when

- [ ] Add @see to 40+ files (91 missing → bring to 155/193)
- [ ] Add per-module test files for common/, commands/, scan/
- [ ] Threshold check added to cpm check

## References

- @see ADR-130 (test architecture)
- @see ADR-126 (traceability by design)
