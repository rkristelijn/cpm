---
summary: Rebrand CPM from "C Package Manager" to "Compliance Process Management" — superseded by informal "code project maturity" (see README.md).
status: superseded
superseded-by: README.md — "code project maturity" is the canonical expansion since v0.3.0
---

# ADR-008: CPM Rebrand — Compliance Process Management

## Context

CPM started as "C Package Manager" but evolved into something broader: a quality framework with CMMI-inspired levels, shared shell libraries, and check registries. The current consumers (llama-cli, workspace-tui, show-master) all use different languages but need the same engineering discipline.

The name "C Package Manager" no longer fits. The tool doesn't manage C packages — it manages **compliance processes** across any tech stack.

## Decision

Rebrand CPM to **Compliance Process Management**.

### Name rationale

| Letter | Meaning | Why |
|--------|---------|-----|
| C | Compliance | Adherence to quality standards, not just "it works" |
| P | Process | Repeatable workflows, not one-off fixes |
| M | Management | Track, measure, improve over time |

Alternative M-words considered: Monitoring, Mitigation, Maturity — all fit but "Management" is broadest.

### Scope definition

CPM is a **quality layer** that sits on top of any repo. It provides:

```text
┌─────────────────────────────────────────────────┐
│  Your repo (any language, any purpose)          │
├─────────────────────────────────────────────────┤
│  CPM layer                                      │
│  ├── lib/shell/ui.sh    (consistent output)     │
│  ├── lib/shell/log.sh   (audit trail)           │
│  ├── lib/make/*.mk      (quality targets)       │
│  ├── checks/            (level-gated checks)    │
│  └── cpm.toml           (repo config)           │
└─────────────────────────────────────────────────┘
```

### What CPM is NOT

- Not a build system (use make/cmake/npm/cargo)
- Not a CI system (use GitHub Actions/GitLab CI)
- Not a linter (use eslint/clang-tidy/ruff)
- Not language-specific (plugins handle that)

### What CPM IS

- A **progressive quality gate system** (CMMI 0→5)
- A **shared TUI library** for consistent script output
- A **check registry** that knows what to run at each level
- A **gamification engine** that rewards engineering discipline
- A **knowledge base** of engineering best practices

### CMMI Levels (universal, language-agnostic)

| Level | Gate | Checks |
|-------|------|--------|
| 0.3 | Training Wheels | pre-commit hooks, formatting, ADR template exists |
| 1 | Managed | commit conventions, security scan, basic tests, type safety |
| 2 | Defined | ADR-driven development, complexity limits, coverage >60%, e2e |
| 3 | Quantitative | metrics tracking, slop detection, research freshness, mutation |
| 4 | Optimizing | trend analysis, auto-fix, AI-assisted review, zero-regression |
| 5 | Excellence | full automation, continuous improvement, zero-defect targets |

### Language plugins

| Plugin | Provides |
|--------|----------|
| `cpp` | clang-tidy, cppcheck, pmccabe, doxygen |
| `typescript` | biome, vitest, tsc --noEmit |
| `python` | ruff, mypy, pytest |
| `shell` | shellcheck, shfmt |
| `docs` | rumdl, ADR validation, xref checks |

### Integration (consumer perspective)

```bash
# In any repo:
cpm init --lang=typescript --level=1
# Creates: cpm.toml, .cpm/ directory, basic hooks

cpm status
# 🎮 Level 1: Managed (Score: 72/100)
# Next: Add complexity checks to reach Level 2

cpm check
# Runs level-appropriate checks

cpm level up
# Shows what's needed for next level
```

## Consequences

- CPM becomes the single source of truth for quality tooling
- llama-cli's 120+ scripts gradually delegate generic checks to cpm
- New repos get instant quality infrastructure via `cpm init`
- The gamification motivates progressive improvement
- Engineering knowledge accumulates in one place, benefits all repos

## References

- @see lib/shell/ui.sh (shared TUI)
- @see lib/shell/log.sh (audit trail)
- @see adr-006-quality-framework-vision.md (original vision)
- @see ../llama-cli/docs/adrs/adr-121-cpm-quality-layer.md (consumer ADR)
