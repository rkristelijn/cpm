---
title: dual audit trail — embedded @see + external traceability matrix
type: feat
created: 2026-05-19T08:24:00+00:00
labels: [feat, traceability]
remote:
---

## What

Two forms of audit trail that complement each other:

1. **Embedded (in code/docs):** `@see ADR-xxx`, `Closes: slug`, `@trace feature:xxx`
2. **External (generated):** `.tmp/traceability-matrix.json` — auto-generated from embedded refs

The matrix is the "proof" — a queryable index of all links between artifacts.

## Why

Embedded refs are the source of truth (live with the code). But you can't query them easily or detect gaps without an external index. The matrix is generated (not maintained), so it's always fresh.

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: Auditable decisions, traceable changes, detectable drift between code and docs.

## Acceptance criteria

- [ ] AC1: `cpm trace` generates traceability matrix from @see/@trace annotations
- [ ] AC2: Matrix shows: file → ADR, file → issue, file → test
- [ ] AC3: `cpm trace --gaps` shows files without any traceability link
- [ ] AC4: `cpm trace --stale` shows links where code is newer than linked doc

## Done when

- [ ] Acceptance criteria met
- [ ] Integrates with existing check-stale-docs.sh and check-xref-validate.sh
- [ ] No regression

## References

- @see ADR-126 (traceability by design)
- @see ADR-016 (traceability matrix)
- @see checks/universal/docs/check-stale-docs.sh
