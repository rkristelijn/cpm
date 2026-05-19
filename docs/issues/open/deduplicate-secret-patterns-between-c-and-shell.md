---
title: deduplicate secret patterns between C++ and shell
type: refactor
created: 2026-05-19T05:02:29+00:00
labels: [refactor, tech-debt]
remote:
---

## What

Secret detection patterns exist in both `src/checks/secrets.cpp` and `checks/universal/security/check-secrets-fast.sh`. Consolidate to one source of truth.

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: Adding a new secret pattern requires one change, not two. Reduces risk of drift between implementations.

## Acceptance criteria

- [ ] AC1: Secret patterns defined in exactly one location → test: test_e2e_no_pattern_duplication
- [ ] AC2: Both C++ scan and shell check detect the same secrets → test: test_e2e_secrets_parity
- [ ] AC3: Adding a pattern to the source propagates to both runners → test: test_unit_pattern_loading

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

- @see ADR-129 (unified findings contract — deduplication rules)
- @see src/checks/secrets.cpp (C++ implementation)
- @see checks/universal/security/check-secrets-fast.sh (shell implementation)
