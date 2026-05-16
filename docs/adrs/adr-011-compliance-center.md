---
summary: cpm as compliance center — scoped enforcement, smart suggestions, issue tracking integration.
status: proposed
---

# ADR-011: Compliance Center — Scoped Enforcement & Developer Guidance

## Context

Different repos need different compliance levels. Work repos enforce security scanning, personal repos don't. But the tooling should be the same — just the enforcement level differs.

## Decision

### Scoped enforcement via global config

```toml
# ~/.config/cpm/cpm.toml (global)

# Default for all repos: relaxed
[defaults]
enforcement = "suggest"   # suggest | warn | enforce

# Work repos: strict
[[scopes]]
match = "~/git/lab/*"
enforcement = "enforce"
tools = ["gitleaks", "semgrep", "checkov"]

[[scopes]]
match = "~/git/hub/llama-cli"
enforcement = "enforce"
tools = ["gitleaks", "semgrep"]

# Personal repos: relaxed
[[scopes]]
match = "~/git/hub/personal"
enforcement = "suggest"
```

### Enforcement levels

| Level | Behavior | Use case |
|-------|----------|----------|
| `suggest` | Show tip, don't block | Personal projects, experiments |
| `warn` | Show warning, don't block | Open source, learning |
| `enforce` | Block commit/push on failure | Work, production, compliance |

### Smart tool resolution (no duplicates)

```text
cpm check → needs gitleaks
  1. Is gitleaks in PATH (global install)? → use it
  2. Is it in .cpm/bin/ (project-local)? → use it
  3. Not found → suggest install (based on enforcement level)
     enforce → "gitleaks required. Install? [g]lobal / [p]roject"
     suggest → "tip: gitleaks improves security scanning"
```

### Developer guidance (not just errors)

When cpm detects an issue, it provides:

```text
  ⚠ No security scan configured for this repo.

  Why: gitleaks detects secrets before they reach git history.
  Fix: cpm config set tools.gitleaks 8.18.2
  Docs: https://github.com/rkristelijn/cpm/blob/main/docs/adrs/adr-011.md
  Skip: cpm config set -g enforcement suggest (for this repo pattern)
```

Every message has: **what** (the issue), **why** (motivation), **fix** (exact command), **docs** (link to ADR), **skip** (how to opt out).

### Issue creation integration

When you hit a problem that needs tracking:

```bash
cpm issue "gitleaks false positive on test fixture"
  → checks existing issues first (fuzzy match)
  → if similar exists: "Found: #42 'gitleaks config for test files'. Add comment? [y/n]"
  → if new: creates issue with context (repo, file, check, config)
```

### Oopsie detection (proactive suggestions)

cpm watches for patterns and suggests improvements:

```text
$ git push
  cpm: you pushed a .env file 3 commits ago.
  Suggestion: add .env to .gitignore and run: git filter-branch
  Create issue? [y/n/skip]
```

Triggers:
- Secrets in history (even if removed)
- Large binary files committed
- Missing test for new source file
- Stale TODO older than 30 days
- Dependency with known vulnerability

## Consequences

- Work repos get strict compliance without manual setup
- Personal repos stay lightweight
- No duplicate tool installs (global → local fallback)
- Developers get guidance, not just errors
- Issues are tracked, not forgotten
- Existing issues are found before duplicates are created

## References

- @see docs/adrs/adr-010-resolution-strategy.md (config resolution)
- @see docs/adrs/adr-009-package-distribution.md (tool installation)
- @see docs/adrs/adr-121-cpm-quality-layer.md (check registry, severity)
