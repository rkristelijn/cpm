# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [0.10.0] — 2026-08-31

### Added

- **`cpm hook --global`** — one-command global pre-commit hooks (26 checks, ~225ms)
- `--status`, `--enable`, `--disable`, `--check`, `--remove` subcommands
- 3 autofix checks: trailing whitespace, end-of-file newline, CRLF→LF
- 11 blocking checks: gitleaks, semgrep, secrets-fast, PII (13 patterns NL/EU/UK/US), large files, dangerous shell, branch protection, conflict markers, artifacts (~37 patterns), JSON/YAML syntax, broken symlinks
- 9 warning checks: gitignore, debug statements, binaries, empty files, mixed endings, naming conventions (auto-detects React PascalCase), typos (via typos-cli), DEI violations (38 terms), absolute paths
- 2 commit-msg checks: conventional commits, WIP blocking
- Per-repo override via `cpm.toml [hooks.global]`
- Auto-dedup: skips checks the repo already handles
- Warning mode with interactive prompt (y/N)
- Doc URL in every warning/error output
- Global config: `~/.config/cpm/hooks.conf`
- 38 e2e tests + 8 override scenario tests
- Complete documentation: `docs/features/hooks.md`, `docs/checks/hook-overview.md`, 26 individual check docs

### Added

- Full JavaScript/TypeScript check suite (package.json, tsconfig, react, nextjs, angular, nx)
- Testing checks (Jest, Vitest, Cypress, Playwright)
- Universal quality checks (CSS, HTML, JSON, XML, web essentials)
- Java/Spring checks (13 anti-patterns)
- Reverse-engineering toolkit (overview, techradar, callgraph, classdiagram, trace, etc.)
- `cpm analyse` command with conditional stack detection
- JSONL findings database with queryable output
- Third-party tool integration (gitleaks, semgrep, trivy, osv-scanner, checkov)
- Git health analysis (bus factor, commit hygiene, process detection)
- Test quality and documentation quality analyzers
- Autofix script (safe + risky categories)
- Recursion guard to prevent fork bombs

### Fixed

- `cpm_grep` now filters non-existent paths (prevents resource exhaustion)
- `fork()` failure in runner.cpp gracefully skips remaining checks
- Techradar false positives (now excludes checks/scripts/docs from scan)

### Changed

- Reorganized checks: typescript/ merged into javascript/
- Universal checks split into security/, quality/, docs/, deps/ subdirs
- All shell scripts now support `cpm_check_enabled` for disable via cpm.toml
