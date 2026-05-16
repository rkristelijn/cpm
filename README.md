# cpm — Compliance Process Management

> AI writes the code. cpm keeps it good.

A quality layer between git and your code. Learns with you, grows with you, never blocks without teaching.

## What's your cpm level?

```bash
$ cpm maturity

  Maturity Audit (inspired by CMMI, DORA, OpenSSF, 12-factor)

  Level: 2 (Defined)
  Score: 12/18

  ✓ formatting    ✓ secrets scan    ✓ hooks
  ✓ tests         ✓ CI pipeline     ✓ architecture docs
  ✗ metrics       ✗ slop detection  ✗ trend analysis

  Next: cpm enable metrics
```

## Why

With AI-assisted development (Copilot, Cursor, Claude, local models), code is written faster than ever. But faster doesn't mean better:

- AI generates **slop** — verbose, repetitive, over-engineered code
- AI forgets **tests**, **docs**, and **security**
- Juniors **accept everything** without review
- Seniors **can't review fast enough**

cpm is the guardrail. It enforces best practices regardless of who (or what) writes the code.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh | bash
```

Then in any repo:

```bash
cpm init        # generates cpm.toml with sensible defaults
cpm maturity    # shows your current level
cpm check       # runs quality checks
```

## How it works

```text
  You / AI → code → cpm → git → remote
                     ↑
                     formats, lints, scans
                     teaches why
                     tracks progress
```

cpm sits in git hooks. It runs checks before commit and push. It's as intrusive as you want:

| Level | Behavior | For whom |
|-------|----------|----------|
| `learn` | Tips after commit | Getting started |
| `guide` | Warnings before push | Growing teams |
| `guard` | Block push on errors | Mature projects |
| `enforce` | Block commit on errors | Production, compliance |

## Features

- **37+ checks** out of the box (formatting, security, complexity, slop, PII, licenses)
- **Language plugins** — C++, TypeScript, Python, Rust, Java (add a directory)
- **Zero deps** — bash + git, works offline
- **Fast** — pre-commit < 5s, pre-push < 60s
- **Timing + trends** — know when things get slower
- **Delta-aware** — only checks what changed
- **JUnit XML** — integrates with any CI
- **Configurable** — `cpm.toml` is the single source of truth
- **Maturity progression** — levels unlock naturally as you grow

## Maturity Levels

| Level | Name | What you get |
|-------|------|-------------|
| 0 | Initial | `cpm init` — formatting + secrets |
| 1 | Managed | + hooks, tests, conventional commits |
| 2 | Defined | + architecture docs, complexity, CI, coverage |
| 3 | Measured | + metrics, trends, slop detection, mutation testing |
| 4 | Optimized | + auto-remediation, AI review, zero-defect targets |

Inspired by CMMI, DORA, OpenSSF Scorecard, ISO 25010, and 12-factor methodology.

## Quick start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh | bash

# Initialize in your repo
cd my-project
cpm init

# Check your level
cpm maturity

# Run checks
cpm check fast      # <5s, pre-commit
cpm check           # default, pre-push
cpm check full      # everything, CI

# Demo the UI
cpm demo
```

## Configuration

```toml
# cpm.toml — single source of truth
[project]
name = "my-project"
lang = "cpp"              # cpp | typescript | python | rust | java

[enforcement]
level = "guide"           # learn | guide | guard | enforce

[tools]
clang-format = "19"
shellcheck = "0.10.0"
gitleaks = "8.18.2"

[ui]
spinner = "random"        # dots, arc, pipe, arrow, random
```

## Philosophy

1. **Learning over policing** — every message teaches
2. **Simple bolt-on** — works on any existing repo
3. **Grow with you** — start at level 0, reach level 4 at your pace
4. **Industry standards** — not invented here, curated from the best
5. **AI-ready** — guardrails for vibe coding

## License

MIT
