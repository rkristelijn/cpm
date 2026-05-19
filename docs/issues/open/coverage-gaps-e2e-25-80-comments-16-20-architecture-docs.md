---
title: coverage gaps — e2e 25%→80%, comments 16%→20%, architecture docs
type: feat
created: 2026-05-19T09:25:00+00:00
labels: [feat, quality]
remote:
---

## What

Close remaining coverage gaps:

| Metric | Current | Target |
|--------|---------|--------|
| E2E command coverage | 25% (8/32) | 80% (26/32) |
| Comment ratio | 16% | 20% (cpm.toml threshold) |
| Architecture docs | 0 C4 diagrams | Context + Container diagram |
| Design per module | 5 generic drawio | 1 per feature module |

## Why

We enforce these metrics on others via checks. Dogfooding requires meeting our own thresholds.

## Value

- Quality characteristic: Maintainability + Usability
- Stakeholder benefit: Every command is tested, code is documented, architecture is visible.

## Acceptance criteria

- [ ] AC1: E2E tests exist for 26+ commands (test_*.sh per command group)
- [ ] AC2: `cloc src/` shows ≥20% comment ratio
- [ ] AC3: docs/designs/ has C4 context + container diagram
- [ ] AC4: `cpm check` comment-ratio passes on own repo

## Done when

- [ ] Acceptance criteria met
- [ ] No regression
- [ ] check-comment-ratio.sh runs and passes

## References

- @see ADR-130 (test architecture)
- @see cpm.toml [checks.comment-ratio] threshold = 20
- @see docs/designs/ (existing drawio files)
