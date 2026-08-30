# ADR-138: Industry Repository Standards

*Status*: partially-implemented · *Date*: 2026-05-20 · *Author*: kiro

## Context

Analysis of top 50 GitHub repositories (by stars) reveals consistent patterns in repository organization, meta files, and processes. These standards can be codified into cpm checks.

## Methodology

- Cloned 50 top-starred repos from GitHub
- Analyzed directory structures, meta files, and documentation patterns
- Cross-referenced with industry best practices

## Findings

### Directory Structure (Top-Level)

```text
├── build/              # Compiled files (or `dist/`)
├── docs/               # Documentation (or `doc/`)
├── src/                # Source code (or `lib/` for libs, `app/` for apps)
├── test/               # Automated tests (or `spec/`, `tests/`)
│   ├── unit/
│   ├── integration/    # (or `e2e/`)
│   └── benchmarks/
├── tools/              # Utilities and scripts
├── LICENSE
└── README.md
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Folders | lowercase, kebab-case | `build-tools`, `src` |
| Files | lowercase or PascalCase | `README.md`, `UserController.ts` |
| Classes | PascalCase | `UserService` |
| Variables | camelCase | `userName` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRIES` |

### Meta Files (Root) - Based on 50 Repos Analysis

| File | Purpose | Present | % |
|------|---------|---------|---|
| LICENSE | Open source license | 50/50 | 100% |
| README.md | Project documentation | 49/50 | 98% |
| .gitignore | Git exclusions | 46/50 | 92% |
| .github/workflows | CI/CD pipelines | 45/50 | 90% |
| CONTRIBUTING.md | Contribution guidelines | 30/50 | 60% |
| .editorconfig | Editor-agnostic formatting | 24/50 | 48% |
| scripts/ | Build/utility scripts | 19/50 | 38% |
| CODE_OF_CONDUCT.md | Community standards | 19/50 | 38% |
| SECURITY.md | Security policy | 20+/50 | 40%+ |
| docs/ | Documentation folder | 14/50 | 28% |
| .vscode/ | VSCode settings | 14/50 | 28% |
| CLAUDE.md / AGENTS.md | AI agent config | 14/50 | 28% |
| src/ | Source code folder | 13/50 | 26% |
| .devcontainer/ | Dev container config | 12/50 | 24% |
| .claude/ | Claude agent config | 11/50 | 22% |
| test/ or tests/ | Test folder | 18/50 | 36% |
| CHANGELOG.md | Version history | 10/50 | 20% |
| .husky/ | Git hooks | 6/50 | 12% |

### Documentation Patterns

**Root-level docs (major frameworks):**

| Repo | Docs Found |
|------|------------|
| react | CHANGELOG.md, CLAUDE.md, CODE_OF_CONDUCT.md, CONTRIBUTING.md, README.md, SECURITY.md |
| next.js | AGENTS.md, CLAUDE.md, CODE_OF_CONDUCT.md, UPGRADING.md, contributing.md, license.md, readme.md |
| node | BUILDING.md, CHANGELOG.md, CODE_OF_CONDUCT.md, CONTRIBUTING.md, GOVERNANCE.md, README.md, SECURITY.md, glossary.md, onboarding.md |
| electron | CLAUDE.md, CODE_OF_CONDUCT.md, CONTRIBUTING.md, README.md, SECURITY.md |
| n8n | AGENTS.md, CHANGELOG.md, CLAUDE.md, CODE_OF_CONDUCT.md, CONTRIBUTING.md, CONTRIBUTOR_LICENSE_AGREEMENT.md, LICENSE.md, README.md, SECURITY.md |

**Docs folder structure (major frameworks):**

| Repo | Structure |
|------|-----------|
| next.js | 01-app/, 02-pages/, 03-architecture/, 04-community/ |
| electron | api/, tutorial/, development/, faq.md, glossary.md |
| flutter | contributing/, ecosystem/, examples/, releases/, roadmap/ |
| d3 | api.md, community.md, per-module docs |

### Emerging Standards (2024-2025)

| Pattern | Description | Adoption |
|---------|-------------|----------|
| AI Agent Config | CLAUDE.md or AGENTS.md for AI assistants | 28% |
| Dev Containers | .devcontainer/ for reproducible dev environments | 24% |
| Security Policy | SECURITY.md as explicit security contact | 40%+ |
| Governance Docs | GOVERNANCE.md, ONBOARDING.md for large projects | 5% |
| Modular Docs | Numbered folders (01-*, 02-*) for structured docs | 5% |

### EditorConfig Standard

```ini
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
```

### Processes (Top Repos)

1. **PR workflow**: feature branch → PR → review → merge
2. **CI/CD**: GitHub Actions for every PR (90% adoption)
3. **Versioning**: Semantic versioning (semver)
4. **Releases**: GitHub Releases with changelog
5. **Issue tracking**: Templates for bugs/features

### License Distribution

- MIT: 39.4%
- Apache 2.0: 15%
- GPL: 10%
- Others: 35.6%

## Decision

Add cpm checks for:

### Tier 1 - Essential (Must Have)

| Check | Target | Rationale |
|-------|--------|-----------|
| LICENSE | 100% | Legal requirement for open source |
| README.md | 98% | Project entry point |
| .gitignore | 92% | Git hygiene |
| .github/workflows/ | 90% | CI/CD standard |

### Tier 2 - Community (Should Have)

| Check | Target | Rationale |
|-------|--------|-----------|
| CONTRIBUTING.md | 60% | Contributor onboarding |
| CODE_OF_CONDUCT.md | 38% | Community standards |
| SECURITY.md | 40% | Security disclosure |
| .editorconfig | 48% | Editor consistency |

### Tier 3 - Modern (Emerging 2024-2025)

| Check | Target | Rationale |
|-------|--------|-----------|
| CLAUDE.md / AGENTS.md | 28% | AI agent context |
| .devcontainer/ | 24% | Reproducible dev |
| .vscode/ | 28% | Editor settings |

### Structure Checks

- Required: `src/` or `lib/` or `app/`
- Recommended: `docs/`, `test/` or `tests/`
- Optional: `build/`, `scripts/`, `tools/`

### Documentation Quality Checks

- README.md must contain: setup, test, deploy instructions
- CONTRIBUTING.md must exist for external contributions
- SECURITY.md must have contact information

## Rationale

- **Evidence-based**: Analysis of 50 top-starred repos
- **Tiered approach**: Essential vs. emerging standards
- **Future-proof**: Accounts for AI agent configuration trend
- **Actionable**: Each check has clear pass/fail criteria

## cpm Scan Results (50 Top Repos)

Running `cpm scan` on the 50 repos produced:

- **Errors**: 3 (all `no-lockfile`)
- **Warnings**: 161
- **Maturity**: Level 4: 1, Level 3: 20, Level 2: 14, Level 1: 12, Level 0: 3

Top findings:

- `no-agent-config`: 33/50 (66%)
- `unpinned-deps`: 20/50 (40%)
- `no-tests`: 20/50 (40%) — mostly false positives on docs repos
- `no-contributing`: 20/50 (40%)
- `no-build-system`: 16/50 (32%) — false positives on docs repos

See [ADR-139](adr-139-scan-gap-analysis.md) for full gap analysis.

## Consequences

- New checks in `scan_checks.cpp`:
  - `meta-license`
  - `meta-readme-quality`
  - `meta-gitignore`
  - `meta-workflows`
  - `meta-contributing`
  - `meta-code-of-conduct`
  - `meta-security`
  - `meta-editorconfig`
  - `meta-ai-config` (CLAUDE.md/AGENTS.md)
  - `meta-devcontainer`
- Maturity level adjustments (Level 3+ requires Tier 2)
- Documentation updates in `docs/quality-checks.md`
- Gap analysis and implementation plan in ADR-139
