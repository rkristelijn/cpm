---
title: reorganize src/checks and docs/adrs into subdirectories (exceeds 20 files-per-dir)
type: refactor
created: 2026-05-19T05:02:29+00:00
labels: [refactor, tech-debt]
remote:
---

## What

- `src/checks/` has 34 files (limit: 20) → split into `src/checks/security/`, `src/checks/quality/`, `src/checks/deps/`, `src/checks/style/`
- `docs/adrs/` has 143 files (limit: 20) → split into `docs/adrs/architecture/`, `docs/adrs/process/`, `docs/adrs/checks/`, `docs/adrs/external/`

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: cpm dogfoods its own files-per-dir limit. Developers find related ADRs faster via categorized directories.

## Acceptance criteria

- [ ] AC1: No directory exceeds 20 files → test: test_e2e_self_scan (check-file-size)
- [ ] AC2: All @see references still resolve after move → test: cpm xref
- [ ] AC3: Build succeeds (include paths updated) → test: make build

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

- @see cpm.toml [limits] files-per-dir = 20
- @see ADR-126 (traceability — xref validation after moves)
