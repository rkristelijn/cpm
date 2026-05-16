# ADR-002: Feature Parity — cpm vs llama-cli Makefile

*Status*: Accepted · *Date*: 2026-05-03

## Context

cpm aims to be a zero-config replacement for the Makefile-based workflow developed in llama-cli. After the first round of fixes (recursive build, cppcheck `-I src`, rumdl defaults, TOML parser), it's time to measure feature coverage.

## Comparison

### ✅ Covered by cpm

| Category | llama-cli Makefile | cpm |
|----------|-------------------|-----|
| Build | `make build` | `cpm build` (Makefile → CMake → compiler fallback) |
| Test (unit) | `make test-unit` | `cpm test` (Makefile → CTest → compiler fallback) |
| Format C++ | `make format-code` (clang-format) | `cpm format` |
| Format Markdown | `make format-md` (rumdl) | `cpm format` |
| Format YAML | `make format-yaml` | `cpm format` |
| Format Scripts | `make format-scripts` (shfmt) | `cpm format` |
| Lint C++ | `make lint-cppcheck` | `cpm lint` (cppcheck -I src) |
| Lint clang-tidy | `make tidy` | `cpm lint` (code-cpp-quality-lint) |
| Lint Markdown | `make lint-md` (rumdl) | `cpm lint` |
| Lint YAML | `make lint-yaml` (yamllint) | `cpm lint` |
| Lint Scripts | `make lint-scripts` (shellcheck) | `cpm lint` |
| Lint Makefile | `make lint-makefile` | `cpm lint` |
| Complexity | `make complexity` (pmccabe) | `cpm lint` |
| Comment ratio | `make comment-ratio` (cloc) | `cpm lint` |
| Doxygen | `make docs` | `cpm lint` |
| SAST security | `make sast-security` (semgrep) | `cpm lint` |
| SAST secrets | `make sast-secret` (gitleaks) | `cpm lint` |
| Setup | `make setup` | `cpm install` |
| Git hooks | `make hooks` | `cpm hook` / `cpm unhook` |
| Version bump | `make bump` | `cpm bump` |
| Tool versions | `.config/versions.env` | `cpm.toml [tools]` + `cpm audit` |

**cpm-only features (not in llama-cli Makefile):**

| Feature | Command |
|---------|---------|
| Scaffolding | `cpm new <project>` / `cpm init` |
| Module generator | `cpm new module <name>` |
| Test generator | `cpm new test <name>` |
| Config management | `cpm get` / `cpm set` |
| Eject to Makefile/CMake | `cpm eject` |
| Zero-config defaults | Built-in clang-format, rumdl, yamllint, cppcheck defaults |

### ❌ Missing from cpm

| Feature | llama-cli | Priority | Notes |
|---------|-----------|----------|-------|
| Tiered quality gates | `check-fast` / `check` / `check-full` | High | cpm only has `lint` (all-or-nothing) |
| Coverage | `make coverage` + `coverage-report` | High | gcov/lcov integration |
| Run | `make start` / `make run` | High | Build + execute in one step |
| E2E tests | `make e2e` | Medium | Separate test tier |
| Smart pre-push | `scripts/dev/prepush.sh` | Medium | Only check changed files |
| File size check | `make file-size` | Low | Policy check |
| Consistency check | `make consistency` | Low | Code consistency policy |
| Mutation testing | `make mutation` (Mull) | Low | Very slow, PR-only |
| Fuzz testing | `make fuzz` | Low | Requires llvm fuzzer |
| TODO tracker | `make todo` → TECHDEBT.md | Low | Extracts TODOs from code |
| Changelog | git-cliff | Low | Conventional commits |
| GitHub integration | `make gh-create-pr` etc. | Low | gh CLI wrappers |
| Condensed output | `make check-ai` | Low | Machine-readable output |

### Scorecard

| | cpm | llama-cli |
|---|---|---|
| Lint/format checks | 13 | 13 |
| Format actions | 4 | 4 |
| Quality tiers | 1 | 3 |
| Test tiers | 1 | 4 (unit/e2e/fuzz/mutation) |
| Zero-config | ✅ | ❌ |
| Scaffolding | ✅ | ❌ |
| Config management | ✅ | ❌ |
| Lines of config needed | 1 (cpm.toml) | ~500 (Makefile + scripts + .config/) |

## Decision

Core quality workflow is at parity. Roadmap for v0.2.0:

1. `cpm run` — build + execute
2. `cpm check` tiered gates — fast (format+build), full (lint+test), exhaustive (+coverage+sast)
3. `cpm coverage` — gcov/lcov integration
4. Smart checks — only check changed files (git diff based)

## Consequences

- cpm is usable as a drop-in for new C/C++ projects
- Existing projects with Makefile can migrate gradually
- llama-cli stays on Makefile for now (too many custom targets)
