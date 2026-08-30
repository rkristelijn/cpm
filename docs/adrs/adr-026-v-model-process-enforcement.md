---
summary: Enforce the V-model process through git hooks, tied to maturity levels.
status: partially-implemented
---

# ADR-026: V-Model Process Enforcement

## Context

cpm claims maturity level 3, but nothing prevents bypassing the process: committing directly to main, skipping tests, pushing without a linked issue. The V-model is documented but not enforced.

## Decision

Enforce the V-model through a chain of checks at each git lifecycle point. Each check maps to a maturity level — you only get enforced what your level requires.

### The chain

```text
Roadmap/Sprint → Issue (status: ready) → Branch (from issue) → Code + Tests → Commit → Push → PR → Release
```

Each link in the chain is a check:

| Check | What it enforces | Maturity level |
|-------|-----------------|----------------|
| Branch from issue | No branch without a ticket | 2 |
| No commit on main | Must use feature branch | 2 |
| Code requires tests | No src/ change without test | 3 |
| Commit links issue | Commit references issue # | 3 |
| Acceptance criteria | Issue has DoD/acceptance | 3 |
| No push without PR | Block direct push to main | 2 |
| Release has regression | Tag requires test pass | 4 |
| Issue in ready status | Ticket must be "ready" before branch | 4 |

### When checks run

```text
┌─────────────────────────────────────────────────────────┐
│ pre-commit                                              │
│   Level 2: block commit on main                         │
│   Level 3: code change requires test in same commit     │
├─────────────────────────────────────────────────────────┤
│ commit-msg                                              │
│   Level 1: conventional commit format                   │
│   Level 3: must reference issue (closes #N, refs #N)    │
├─────────────────────────────────────────────────────────┤
│ pre-push                                                │
│   Level 2: block push to main                           │
│   Level 3: all checks pass                              │
│   Level 4: issue in correct status                      │
├─────────────────────────────────────────────────────────┤
│ cpm issue branch                                        │
│   Level 2: issue must exist                             │
│   Level 4: issue must be in "ready" status              │
├─────────────────────────────────────────────────────────┤
│ cpm release                                             │
│   Level 3: all tests pass                               │
│   Level 4: regression suite + acceptance criteria met   │
└─────────────────────────────────────────────────────────┘
```

### Configuration

```toml
# cpm.toml
[enforcement]
level = "guard"          # learn | guide | guard | enforce

[process]
maturity-target = 3      # which level's checks to enforce
require-branch = true    # no commit on main
require-issue = true     # commit must reference issue
require-tests = true     # code change needs tests
require-acceptance = false  # issue needs acceptance criteria (level 4)
```

Or simply: set your maturity target and cpm enforces everything up to that level.

```toml
[process]
maturity-target = 3
# Implies: require-branch, require-issue, require-tests
# Does NOT imply: require-acceptance, require-regression (level 4)
```

### Override per workflow

```bash
cpm commit --workflow hotfix    # relaxed: skip issue requirement
cpm commit --workflow feature   # strict: full V-model
```

### V-model mapping

```text
Level 2 (Defined):
  Motivate  → Issue exists with description
  Design    → Branch created from issue
  Code      → Feature branch, conventional commits
  Verify    → Push blocked without checks passing

Level 3 (Quantitative):
  Motivate  → Issue has acceptance criteria
  Design    → ADR for architectural changes
  Code      → Tests accompany code changes
  Verify    → Issue referenced in commits (traceability)
  Measure   → Coverage, complexity, timing tracked

Level 4 (Optimized):
  Motivate  → Issue in "ready" status (groomed, estimated)
  Design    → Architecture tests enforce boundaries
  Code      → Mutation testing, no dead code
  Verify    → Regression suite passes before release
  Release   → Automated, boring, repeatable
```

## Consequences

### Positive

- Process is enforced, not just documented
- Gradual: start at level 1, grow to level 4
- Traceable: every code change links to a reason (issue)
- Configurable: override per-check or per-workflow

### Negative

- Can feel restrictive (but that's the point at higher levels)
- `--no-verify` always available as escape hatch

## References

- @see docs/v-model.md
- @see docs/adrs/adr-025-local-first-issue-tracking.md
- @see docs/features/enforcement-levels.md
