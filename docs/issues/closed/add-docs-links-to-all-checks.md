---
title: add docs links to all checks
type: feat
created: 2026-05-19T05:02:29+00:00
labels: [feat, usability]
remote:
---

## What

Create `docs/checks/` directory with one .md per check. Add `docs` field to every `findings_add` call and every C++ Finding.

## Why

ADR-020 states: "Every finding has: what, why, fix, docs". Currently 0/77 checks provide a docs link. Users can't learn *why* a finding matters.

## Value

- Quality characteristic: Usability
- Stakeholder benefit: Every finding links to documentation explaining the rationale, examples, and how to opt out. Supports "learn don't police" philosophy.

## Acceptance criteria

- [ ] AC1: `docs/checks/` contains one .md per active check → test: test_e2e_docs_coverage
- [ ] AC2: Every `findings_add` call has a non-empty `docs` parameter → test: test_e2e_finding_fields
- [ ] AC3: Every C++ Finding has a non-empty `docs` field → test: test_unit_check_docs

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

- @see ADR-020 (product vision — "every finding has docs")
- @see ADR-013 (learn don't police)
- @see ADR-129 (unified findings contract — docs field)
