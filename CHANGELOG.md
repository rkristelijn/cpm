# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

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
