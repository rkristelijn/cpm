# ADR-001: cpm — C Project Manager Concept

> 🟢 **Status: Superseded** — Original 'C Package Manager' concept. cpm evolved into 'code project maturity'. See [ADR-008](adr-008-rebrand-compliance-process-management.md).

*Status*: Superseded · *Date*: 2026-04-12 · *Author*: rkristelijn

## Context

Every new C/C++ project starts with the same boilerplate:

- `CMakeLists.txt` with test targets
- `Makefile` with `all`, `test`, `check`, `format`, `install`, `setup` targets
- `.clang-format` config
- `.github/workflows/ci.yml` with format, test, doxygen, cppcheck, semgrep, gitleaks
- `Doxyfile`
- `scripts/setup.sh` for dependency installation
- `docs/adr/` structure

This is copy-pasted from project to project, diverges over time, and has no upgrade path.

npm solved this for JavaScript: `npm init` scaffolds a project, `npm install` manages dependencies, `npm publish` releases it. C has no equivalent.

## Problem

| Pain point | npm solution | C today |
|------------|-------------|---------|
| Project scaffold | `npm init` | manual copy |
| Dependency management | `package.json` + lock file | git submodules / CPM.cmake / manual |
| Build | `npm run build` | `make` (inconsistent) |
| Test | `npm test` | `make test` (inconsistent) |
| Publish | `npm publish` | manual tag + release |
| Version pinning | `package-lock.json` | none |

## Decision

Build `cpm` as a CLI tool (written in C or shell) that:

1. `cpm init <name>` — scaffold from a canonical template (based on llama-cli boilerplate)
2. `cpm build` — delegates to `make all`
3. `cpm test` — delegates to `make test`
4. `cpm check` — delegates to `make check`
5. `cpm install` — delegates to `sudo make install`
6. `cpm add <dep>` — adds a CPM.cmake dependency to `CMakeLists.txt`
7. `cpm publish` — bumps version, tags, pushes

## Template source

The canonical template is extracted from `llama-cli`:

- `Makefile` (with all targets)
- `CMakeLists.txt`
- `.config/.clang-format`
- `.config/Doxyfile`
- `.github/workflows/ci.yml`
- `scripts/setup.sh`
- `docs/adr/README.md`
- `src/main.cpp` stub
- `TOOL_VERSIONS`

## Open questions

- Written in C (dogfooding) or shell (simpler bootstrap)?
- Where is the template hosted — this repo, a separate `cpm-template` repo, or embedded?
- How does `cpm add` work — CPM.cmake, git submodule, or a registry?
- Version registry: is there a central index of C packages, or just GitHub URLs?

## Rationale

- llama-cli already has the boilerplate worth codifying
- The npm mental model is widely understood
- Shell-first implementation keeps bootstrap simple (no compiler needed to use cpm)

## Consequences

- `cpm` repo created at `../cpm` (this repo)
- Template extracted from `llama-cli` when stable
- First milestone: `cpm init` that produces a buildable project
