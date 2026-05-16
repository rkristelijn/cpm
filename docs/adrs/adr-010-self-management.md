---
summary: CPM manages itself (dogfooding) — bootstrap path to CMMI Level 3.
status: proposed
---

# ADR-010: Self-Management (CPM manages CPM)

## Context

CPM is a quality framework that claims to work on any repo. The strongest proof is using it on itself. Currently cpm has a `cpm.toml` but only runs C++ checks — while the actual codebase is now primarily **bash** (lib/shell/, checks/universal/).

To reach CMMI Level 3 (Quantitatively Managed), cpm must:
1. Track its own quality metrics over time
2. Have traceability between ADRs, code, and checks
3. Detect regressions in its own process

## Decision

CPM dogfoods itself at progressively higher levels:

### Phase 1: Level 1 (current → immediate)

Update `cpm.toml` to reflect the actual stack:

```toml
[project]
name = "cpm"
version = "0.2.0"
lang = "shell"
build = "make"

[checks]
code-bash-syntax-lint = true        # shellcheck on lib/shell/ + checks/
code-bash-syntax-format = true      # shfmt
docs-markdown-syntax-format = true  # rumdl
meta-generic-vulnerability-scan = true  # gitleaks
```

### Phase 2: Level 2 (architecture + coverage)

- Complexity checks on bash functions (max 15 cyclomatic)
- File size limits (max 300 lines per script)
- ADR exists for each major decision
- Check coverage: every check in `checks/` has a test

### Phase 3: Level 3 (metrics + trends)

- `cpm status` persists score to `.tmp/history.json`
- Trend detection: score must not decrease between commits
- Research freshness: ADRs older than 90 days flagged for review
- Slop detection on own docs
- Traceability: each check maps to an ADR

### Scoring formula

```
Score = (passed_checks / total_checks) × 100
Level = floor(score / 20)  # 0-20=L0, 20-40=L1, 40-60=L2, 60-80=L3, 80-100=L4
```

## Consequences

- cpm eats its own dogfood — bugs in the framework surface immediately
- The `cpm.toml` in this repo becomes the reference example
- Every new check added to `checks/` must pass on cpm itself
- Release blockers: `cpm check` must pass before any tag

## Acceptance Criteria

- [ ] `cpm check` runs successfully on the cpm repo itself
- [ ] `cpm status` shows Level 1+ score
- [ ] Pre-commit hook enforces `cpm check --fast`
- [ ] Score history persisted between runs
- [ ] No check in `checks/` fails on cpm's own code

## References

- @see adr-006-quality-framework-vision.md (CMMI levels)
- @see adr-008-rebrand-compliance-process-management.md (scope)
- @see docs/migration-plan.md (Phase 3: Scoring)
