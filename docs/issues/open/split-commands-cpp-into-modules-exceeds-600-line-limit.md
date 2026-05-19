---
title: split commands.cpp into modules (exceeds 600 line limit)
type: refactor
created: 2026-05-19T05:02:29+00:00
labels: [refactor, tech-debt]
remote:
---

## What

Split `src/commands.cpp` (960 lines) into per-command files: `cmd_check.cpp`, `cmd_scan.cpp`, `cmd_init.cpp`, `cmd_issue.cpp`, etc.

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: Single-responsibility per file. Adding a new command doesn't require touching a 960-line file.

## Acceptance criteria

- [ ] AC1: No source file in src/ exceeds 600 lines → test: test_e2e_self_scan
- [ ] AC2: `cpm help` output unchanged → test: test_e2e_help_regression
- [ ] AC3: All existing commands work identically → test: make test

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

- @see cpm.toml [limits] source-lines = 600
- @see src/commands.cpp (current monolith)
