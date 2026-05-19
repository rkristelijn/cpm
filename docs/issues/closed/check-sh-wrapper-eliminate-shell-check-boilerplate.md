---
title: check.sh wrapper — eliminate shell check boilerplate
type: feat
created: 2026-05-19T05:02:29+00:00
labels: [feat, architecture]
remote:
---

## What

Create `lib/shell/check.sh` that provides: `set -o errexit/nounset/pipefail`, source init.sh, `findings_init`, and `trap findings_finish EXIT`. All shell checks source this instead of repeating boilerplate.

## Why

41 shell checks repeat identical boilerplate (5-10 lines each). This causes copy-paste errors and makes the findings contract opt-in instead of automatic.

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: New checks are 5-10 lines shorter, findings reporting is automatic (can't forget), consistent behavior guaranteed.

## Acceptance criteria

- [ ] AC1: `lib/shell/check.sh` exists with set -o, source init.sh, findings_init, trap → test: test_e2e_check_wrapper
- [ ] AC2: Sourcing check.sh auto-detects check name from filename → test: test_unit_check_name_detection
- [ ] AC3: findings_finish runs on EXIT (even on error) → test: test_e2e_check_error_handling

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (if public API changed)

## References

- @see ADR-129 (unified findings contract)
- @see lib/shell/init.sh (current entry point)
