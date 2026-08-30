---
title: CLI/terminal accessibility rules — check that CLI tools are accessible
type: feat
created: 2026-08-30T09:40:00+02:00
labels: [feat, a11y, rules]
---

## Context

cpm has 120 WCAG rules for web projects but zero checks for CLI/terminal accessibility. There is no formal WCAG equivalent for CLIs, but established guidelines exist:

- **WCAG2ICT** (W3C informative guidance for non-web software)
- **EN 301 549** section 11 (EU legal standard for software accessibility)
- **no-color.org** (community standard, 400+ adopters)
- **clig.dev** (CLI UX guide including accessibility)
- **GitHub CLI a11y work** (2025 case study)

cpm's own output already scores well (NO_COLOR, symbols, role-based theming), but we don't check whether *other* CLI tools follow these practices.

## Problem

A developer builds a CLI tool, runs `cpm check`, and gets web a11y feedback but zero feedback on whether their CLI output is accessible to screen reader users, color-blind users, or users in constrained terminal environments.

## Proposed rules

### Phase 1: NO_COLOR and color handling (5 rules)

These are the highest-value checks — NO_COLOR is the closest thing to a universal CLI a11y standard.

| ID | Engine | Severity | What it checks |
|----|--------|----------|----------------|
| CLI-A11Y-001 | absence | warning | Source files that emit ANSI escapes (`\033[`, `\x1b[`, `\e[`) but never reference `NO_COLOR` — likely ignores the standard |
| CLI-A11Y-002 | pattern | warning | Hardcoded ANSI color codes outside a NO_COLOR guard — should use a color function/variable |
| CLI-A11Y-003 | pattern | info | Color-only status indicators: `\033[31m` or `\033[32m` without an accompanying symbol (✓/✗) or text label (PASS/FAIL) |
| CLI-A11Y-004 | absence | info | CLI entry point (main.cpp, main.go, main.py, index.ts, cli.rs) that never checks `NO_COLOR` — suggest adopting the standard |
| CLI-A11Y-005 | pattern | warning | Raw ANSI 256-color or truecolor escapes (`\033[38;5;`, `\033[38;2;`) — these ignore user terminal theme; prefer ANSI 4-bit colors |

Target: `.cpp`, `.c`, `.go`, `.rs`, `.py`, `.ts`, `.js`, `.rb`, `.sh`, `.bash`
Exclude: `test/`, `tests/`, `vendor/`, `node_modules/`

### Phase 2: Screen reader and assistive tech friendliness (4 rules)

| ID | Engine | Severity | What it checks |
|----|--------|----------|----------------|
| CLI-A11Y-010 | pattern | info | Animated spinner characters (`\r`, cursor movement `\033[A`, `\033[2K`) without TTY detection (`isatty`, `-t 1`, `process.stdout.isTTY`) — breaks screen readers and piped output |
| CLI-A11Y-011 | pattern | info | Box-drawing characters (`─│┌┐└┘├┤`, `═║╔╗╚╝`) in functional output without a `--plain` guard — decorative borders confuse screen readers |
| CLI-A11Y-012 | absence | info | CLI tool with `--help` flag that has no `--json` or `--plain` or `--quiet` flag — machine-readable output helps assistive tech users |
| CLI-A11Y-013 | pattern | warning | Interactive prompt (`readline`, `inquirer`, `dialoguer`, `promptui`) without non-interactive fallback (`--yes`, `--no-input`, `CI` env check) |

### Phase 3: Documentation and discoverability (3 rules)

| ID | Engine | Severity | What it checks |
|----|--------|----------|----------------|
| CLI-A11Y-020 | absence | info | CLI tool entry point without `--help` or `-h` handling |
| CLI-A11Y-021 | file-absence | info | No man page (`man/`, `*.1`, `*.1.md`) in a project with a CLI binary |
| CLI-A11Y-022 | absence | info | README/docs mention colors or styling but never mention `NO_COLOR` or accessibility |

## Scope and targeting

These rules should only fire on projects that ARE CLI tools. Detection heuristic:

- Has a `main()` or CLI entry point
- OR has `bin` field in package.json
- OR has Cargo.toml with `[[bin]]`
- OR has a `cmd/` directory (Go convention)
- OR has `console_scripts` in setup.py/pyproject.toml

The `content_contains` pre-filter on rules handles this naturally: CLI-A11Y-001 only fires if the file contains ANSI escape sequences, which non-CLI code rarely does.

## Implementation approach

All rules are declarative `.rule` files — no C++ code changes needed.

```text
rules/
  a11y/
    CLI-A11Y-001-no-color-support.rule
    CLI-A11Y-002-hardcoded-ansi.rule
    ...
```

Estimated effort: 2-3 hours for Phase 1, 1-2 hours each for Phase 2 and 3.

## Compliance mapping

Add to `compliance.h`:

| Finding rule | Standard | Criterion |
|-------------|----------|-----------|
| `cli-no-color-support` | no-color.org | — |
| `cli-hardcoded-ansi` | WCAG2ICT | 1.4.1 Use of Color |
| `cli-color-only-status` | WCAG2ICT | 1.4.1 Use of Color |
| `cli-no-plain-output` | EN 301 549 | 11.1.3.1 Info and Relationships |
| `cli-spinner-no-tty-check` | WCAG2ICT | 2.2.2 Pause, Stop, Hide |
| `cli-interactive-no-fallback` | EN 301 549 | 11.2.1.1 Keyboard |

## Dogfooding

cpm itself should pass all these rules. Current status:

- CLI-A11Y-001: ✅ (ui.cpp checks NO_COLOR)
- CLI-A11Y-002: ✅ (role-based theming, no raw ANSI in logic)
- CLI-A11Y-003: ✅ (symbols always present)
- CLI-A11Y-010: ⚠ (ui.sh has spinners with TTY check, but verify)
- CLI-A11Y-011: ⚠ (scan output uses `─────`, has NO_COLOR but no `--plain`)
- CLI-A11Y-012: ❌ (no `--json` for `cpm check` output yet)
- CLI-A11Y-013: ✅ (no interactive prompts)

## Priority

Phase 1 first — NO_COLOR rules are the highest value:

- Clear community standard with 400+ adopters
- Easy to verify (regex-based)
- Directly actionable fix suggestions
- Catches real issues (most CLI tools ignore NO_COLOR)

## References

- <https://no-color.org/>
- <https://clig.dev/>
- W3C WCAG2ICT: <https://www.w3.org/TR/wcag2ict-22/>
- EN 301 549 v4.1.0 section 11
- GitHub CLI accessibility: <https://github.blog/engineering/accessibility-at-github/>
- ACM CHI 2021: "Accessibility of Command Line Interfaces"
