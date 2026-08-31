---
title: fix-format: auto-detect and run language-specific formatters on staged files
type: feat
created: 2026-08-31T14:01:57+00:00
labels: [feat, hooks, autofix]
remote:
---

## What

One smart autofix pre-commit check (`fix-format`) that detects the project language from config files and runs the appropriate code formatter on staged files. Formats, re-stages, never blocks.

### Supported formatters

| Language / Ecosystem | Detection file       | Default formatter | Alternatives       |
|----------------------|----------------------|-------------------|-------------------|
| JavaScript/TypeScript | `package.json`      | prettier          | biome, eslint --fix |
| Python               | `pyproject.toml`     | black             | ruff format        |
| Go                   | `go.mod`             | gofmt             | —                  |
| Rust                 | `Cargo.toml`         | rustfmt           | —                  |
| C/C++                | `CMakeLists.txt`, `.clang-format` | clang-format | — |
| Shell                | `*.sh`               | shfmt             | —                  |
| PHP                  | `composer.json`      | phpcbf            | php-cs-fixer       |
| Ruby                 | `Gemfile`            | rubocop -A        | —                  |
| Kotlin               | `build.gradle.kts`   | ktlint -F         | —                  |
| Dart                 | `pubspec.yaml`       | dart format       | —                  |
| Terraform            | `*.tf`               | terraform fmt     | —                  |
| Lua                  | `*.lua`              | stylua            | —                  |

### Auto-detection logic

1. Walk up from `$REPO_ROOT` and match config files:
   - `package.json` → check for `prettier`, `biome`, or `eslint` in devDependencies
   - `pyproject.toml` → check for `[tool.black]` or `[tool.ruff]`
   - `go.mod` → use `gofmt`
   - `Cargo.toml` → use `rustfmt`
   - etc.
2. Only run formatters that are installed (`command -v`)
3. Skip if no matching formatter found

### cpm.toml override

```toml
[format]
formatter = "biome"            # Override auto-detection
args = "--write --no-errors-on-unmatched"  # Custom args
```

## Why

Formatting inconsistencies are the #1 source of noisy diffs and code review friction. Every team wastes time arguing about spaces vs tabs, trailing commas, and bracket placement. An autofix that runs on commit eliminates this entirely — your code is always formatted before it reaches review.

## Value

- Quality characteristic: Maintainability
- Stakeholder benefit: Zero formatting noise in PRs, consistent codebase across all contributors

## Acceptance criteria

- [ ] `fix-format` detects language from project files and runs correct formatter
- [ ] Only staged files are formatted (not entire repo)
- [ ] Fixed files are re-staged with `git add`
- [ ] Exits 0 always (never blocks commit)
- [ ] `cpm.toml [format]` override is respected
- [ ] Skips gracefully when formatter is not installed
- [ ] Works with multiple languages in same repo (monorepo)

## Done when

- [ ] Acceptance criteria met (E2E tests pass)
- [ ] Unit tests added for new code
- [ ] No regression (existing tests pass)
- [ ] Docs updated (hook-fix-format.md created)
- [ ] Added to ALL_CHECKS, hooks.conf, --check health loop

## References

- @see hook-fix-trailing-whitespace.md (same autofix pattern)
- @see hook-fix-end-of-file.md (same autofix pattern)
- @see hook-fix-mixed-endings.md (same autofix pattern)
