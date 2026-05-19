---
title: process-guided development — phase enforcement in hooks
type: feat
created: 2026-05-19T08:13:00+00:00
labels: [feat, process]
remote:
---

## What

Integrate `cpm phase` into git hooks so the process is enforced automatically. Block actions that don't match the current phase. Provide `cpm phase on/off` to enable/disable.

## Why

Developers (and AI agents) get distracted by ideas and skip process steps. Enforcement keeps focus on completing current work before starting new work.

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: Forced focus → faster delivery, fewer half-finished branches, cleaner git history.

## Acceptance criteria

- [ ] AC1: pre-commit hook calls `cpm phase check` and blocks if phase violated
- [ ] AC2: `cpm phase on` enables enforcement, `cpm phase off` disables it
- [ ] AC3: On main without issue → blocks code changes with "create issue first"
- [ ] AC4: Guard log written to `.tmp/phase.log` on every block

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

- @see lib/shell/phase.sh (existing prototype)
- @see ADR-026 (V-model process enforcement)
