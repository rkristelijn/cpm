# CPM — Compliance Process Management

> **Level up your engineering with gamified quality gates.**

```bash
cpm init --lang=typescript --level=1   # Bootstrap quality layer
cpm status                             # 🎮 Level 1: Managed (Score: 72/100)
cpm check                              # Run level-appropriate quality gates
cpm level up                           # See what's needed for next level
```

## Vision

CPM is a **universal quality framework** with gamification. Not language-specific — it layers onto **any repo**: C++, TypeScript, Python, shell, IaC, documentation.

**C** = Compliance (adherence to quality standards)
**P** = Process (repeatable workflows, not one-off fixes)
**M** = Management (track, measure, improve over time)

### Training Wheels → CMMI Excellence

```
Level 0:   Total Anarchy (prototype mode)
Level 0.3: Training Wheels (ADR + acceptance criteria + checks)
Level 1:   Managed (security + types + tests)
Level 2:   Defined (architecture + complexity + coverage)
Level 3:   Quantitatively Managed (metrics + trends)
Level 4:   Optimizing (mutation + AI-assisted)
Level 5:   Excellence (zero defects + full automation)
```

### V-Model per Level

Bij elk level voeg je **links** (requirements) en **rechts** (verification) toe:

```
Level 0.3: ADR requirement → ADR existence check
Level 1:   Security policy → Gitleaks + secret scanning
Level 2:   Architecture → Complexity + structure validation
```

## Language Agnostic

```bash
# TypeScript project
cpm init --language=typescript --level=1

# C++ project
cpm init --language=cpp --level=2

# Python project (community adapter)
cpm init --language=python --level=1
```

## Lifecycle Modes

CPM past zich aan aan je project fase:

- **Prototype**: Minimal checks, fast iteration
- **MVP**: Training Wheels (3 steps)
- **Production**: Full quality gates
- **Maintenance**: Dependency updates + security
- **DR**: Backup + restore verification
- **SLA**: Performance + uptime monitoring

---

## Current Status (v0.1 - C++ only)

**Beta** — C++ implementation with basic quality gates. Vision documented in ADR-006.

### Quick Start (Current)

```bash
cpm new my-app && cd my-app   # scaffold a project
cpm build                      # compile (auto-detects build system)
cpm run                        # build + execute
cpm test                       # run unit tests
cpm lint                       # 13-point quality gate
cpm check                      # format + build + lint + test
```

No Makefile, no CMakeLists.txt, no `.clang-format` needed. cpm uses high-quality internal defaults.

## Install

```bash
cd cpm && make build
sudo cp cpm /usr/local/bin/    # or symlink: ln -s $(pwd)/cpm /usr/local/bin/cpm
cpm install                    # install lint/format tools (brew)
```

## Commands

| Command | Description |
|---------|-------------|
| `cpm new <name>` | Scaffold a new project |
| `cpm new module <name>` | Add src/name.cpp + src/name.hpp |
| `cpm new test <name>` | Add src/name_test.cpp |
| `cpm init` | Create cpm.toml in current directory |
| `cpm build` | Build (Makefile → CMake → compiler fallback) |
| `cpm run` | Build + execute |
| `cpm test` | Run tests (Makefile → CTest → compiler fallback) |
| `cpm lint` | Run all enabled lint checks |
| `cpm format` | Auto-format all files |
| `cpm check [--fast\|--full]` | Tiered quality gate |
| `cpm coverage` | Build with gcov + lcov report |
| `cpm clean` | Remove build artifacts |
| `cpm install` | Install tools from cpm.toml |
| `cpm eject` | Generate Makefile, CMakeLists.txt, config files |
| `cpm bump <major\|minor\|patch>` | Bump version in cpm.toml |
| `cpm hook` / `cpm unhook` | Install/remove git hooks |
| `cpm audit` | Check tool versions |
| `cpm get [key]` / `cpm set <key> <val>` | Read/write config |

## Quality Gate

`cpm lint` runs up to 13 parallel checks:

| Check | Tool | Default |
|-------|------|---------|
| C++ format | clang-format (Google style) | ✅ |
| YAML lint | yamllint | off |
| Markdown lint | rumdl | ✅ |
| Script format | shfmt | off |
| C++ lint | cppcheck (-I src) | ✅ |
| C++ quality | clang-tidy | off |
| Script lint | shellcheck | off |
| Makefile policy | built-in | ✅ |
| Complexity | pmccabe (threshold: 10) | ✅ |
| Comment ratio | cloc (threshold: 20%) | ✅ |
| Doxygen | doxygen | off |
| SAST security | semgrep | off |
| SAST secrets | gitleaks | ✅ |

All checks are configurable via `cpm.toml`. Checks without installed tools are auto-skipped.

## Tiered Quality Gates

```bash
cpm check --fast    # Tier 1: format + build (fast feedback)
cpm check           # Tier 2: + lint + test (default)
cpm check --full    # Tier 3: + coverage (exhaustive)
```

## Configuration

`cpm.toml` — the only file you need:

```toml
[project]
name = "my-app"
version = "0.1.0"
lang = "cpp"
build = "make"

[checks]
code-cpp-syntax-lint = true
code-cpp-quality-lint = false

[checks.code-cpp-syntax-lint]
warn-only = true
```

All settings are optional. cpm works with just `[project] name`.

## Zero-Config Defaults

Without any config files, cpm uses:
- **clang-format**: Google style, 2-space indent, 140 col limit
- **rumdl**: MD013/MD033/MD036/MD041/MD046 disabled, cache in .tmp/
- **yamllint**: 140 char lines, document-start disabled
- **cppcheck**: -I src, suppress missingIncludeSystem
- **build**: recursive find in src/, -I src, excludes *_test.cpp
- **test**: finds *_test.cpp and test_*.cpp in src/ and tests/

## Built With

cpm is written in C++17 and builds itself:

```bash
make build    # produces ./cpm binary
```

## Status

Beta — actively used in [show-master](../show-master). See `docs/adr/` for design decisions.
