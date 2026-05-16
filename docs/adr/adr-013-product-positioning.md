---
summary: cpm sits between git and your code — a learning layer that grows with you.
status: accepted
---

# ADR-013: Product Positioning & Philosophy

## What cpm is

A layer between git and your code that helps you grow as an engineer.

```text
  You → cpm → git → remote
       ↑
       learns with you
       adapts to your level
       never blocks without teaching
```

## Core philosophy

**1. Learning over policing**

cpm is not a gatekeeper. It's a mentor. Every warning explains *why* and links to *how to fix*. You grow in maturity because you understand, not because you're forced.

**2. Intrusive when you want, invisible when you don't**

```toml
# cpm.toml
[enforcement]
level = "learn"    # learn | guide | guard | enforce

# learn:   show tips after commit (non-blocking)
# guide:   show warnings before push (non-blocking)
# guard:   block push on errors, warn on rest
# enforce: block commit on errors + warnings
```

You choose your intensity. Start at `learn`, grow to `enforce` when ready.

**3. Simple bolt-on**

```bash
# Add cpm to any existing repo in 10 seconds:
curl -fsSL https://cpm.dev/install.sh | bash
cd my-project
cpm init
# Done. No config needed. Sensible defaults.
```

No migration. No rewrite. No breaking changes. It bolts on.

**4. Language-agnostic core, language-specific plugins**

```text
lib/cpm/
├── checks/universal/    ← works everywhere (37 checks)
├── checks/cpp/          ← C/C++ projects
├── checks/typescript/   ← TS/JS projects (future)
├── checks/python/       ← Python projects (future)
├── checks/rust/         ← Rust projects (future)
├── checks/terraform/    ← IaC projects (future)
└── checks/java/         ← Java projects (future)
```

Adding a language = adding a directory with checks. No core changes.

**5. Grow with you (maturity progression)**

```text
Level 0: cpm init → formatting + secrets scan
Level 1: + hooks, tests, conventional commits
Level 2: + architecture docs, complexity limits, CI
Level 3: + metrics, trend analysis, mutation testing
Level 4: + auto-remediation, AI-assisted review
```

Each level unlocks naturally. cpm suggests the next step when you're ready:

```text
$ cpm maturity
  Level: 2 (Defined)
  Score: 12/18

  Ready for level 3? Try:
    → cpm enable slop-detection
    → cpm enable timing
```

## Where cpm sits

```text
                    ┌─────────────────────┐
                    │   Your IDE / Editor  │
                    └──────────┬──────────┘
                               │ save
                    ┌──────────▼──────────┐
                    │     Your Code       │
                    └──────────┬──────────┘
                               │ git add
                ┌──────────────▼──────────────┐
                │           cpm               │
                │  ┌─────────────────────┐    │
                │  │ pre-commit: format  │    │
                │  │ pre-push: lint+test │    │
                │  │ post-commit: learn  │    │
                │  └─────────────────────┘    │
                └──────────────┬──────────────┘
                               │ git push
                    ┌──────────▼──────────┐
                    │    CI / Remote      │
                    └─────────────────────┘
```

## What cpm is NOT

- Not a build system (use make, cmake, cargo, npm)
- Not a CI system (use GitHub Actions, GitLab CI)
- Not a linter (it orchestrates linters)
- Not a test runner (it orchestrates test runners)
- Not a package manager (it manages quality tools)

It's the **orchestration and learning layer** between your code and git.

## Competitive positioning

| Tool | Focus | cpm difference |
|------|-------|----------------|
| Husky | Git hooks only | cpm = hooks + checks + learning + metrics |
| lint-staged | Format on commit | cpm = format + lint + security + maturity |
| pre-commit (Python) | Hook manager | cpm = hooks + registry + progression + multi-lang |
| MegaLinter | Run all linters | cpm = linters + teaching + maturity + lightweight |
| SonarQube | Code quality server | cpm = local-first, no server, instant feedback |
| Nx | Monorepo tooling | cpm = any repo, not just monorepos |

## Design constraints

- **Zero runtime deps** — bash + git, nothing else required
- **Offline-first** — works without internet
- **Fast** — pre-commit < 5s, pre-push < 60s
- **Portable** — macOS, Linux, WSL, CI
- **Non-destructive** — never modifies code without consent
- **Inspectable** — `cpm config get`, `cpm maturity`, everything visible

## References

- @see docs/adr/adr-010-resolution-strategy.md
- @see docs/adr/adr-011-compliance-center.md
- @see docs/adr/adr-012-maturity-framework-research.md
