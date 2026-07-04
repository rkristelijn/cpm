# ADR-139: Scan Gap Analysis — Top 50 Repos vs cpm Checks

*Status*: Draft · *Date*: 2026-05-20 · *Author*: kiro

## Context

After scanning 50 top-starred GitHub repos with cpm, we identified patterns that cpm cannot currently detect. These gaps were found by writing ad-hoc shell scripts — proving that cpm should cover them natively.

## Methodology

- Cloned 50 top-starred repos (depth 1) to `~/git/hub/top-repos`
- Ran `cpm scan` → 12 unique check categories triggered
- Manually scripted 20+ additional checks to identify gaps

## Current cpm Check Coverage

| Check | Category | What it detects |
|-------|----------|-----------------|
| `ai-ready` | Meta | AI agent config presence |
| `community` | Meta | LICENSE, README |
| `readme-audit` | Docs | README quality score |
| `package-json` | Deps | lockfile, pinning, description, repository |
| `composer` | Deps | PHP lockfile |
| `python` | Deps | requirements lockfile |
| `cpp` | Code | C++ specific checks |
| `devops` | CI | CI pipeline, .gitignore |
| `testing` | Quality | Test presence |
| `framework-eol` | Deps | EOL detection (Vue, TS, Next.js) |
| `freshness` | Maintenance | Stale repo detection |
| `nextjs-hardening` | Security | Next.js security headers |

## Total: 12 check categories

## Gap Analysis

### Tier 1 — High Value, High Adoption (>50%)

| Missing Check | Adoption | Priority | Rationale |
|---------------|----------|----------|-----------|
| Issue templates | 66% (33/50) | HIGH | Community contribution quality |
| PR templates | 66% (33/50) | HIGH | PR quality and consistency |
| .gitattributes | 58% (29/50) | MEDIUM | Line ending consistency, LFS |
| .editorconfig | 48% (24/50) | HIGH | Editor-agnostic formatting |

### Tier 2 — Medium Value, Medium Adoption (25-50%)

| Missing Check | Adoption | Priority | Rationale |
|---------------|----------|----------|-----------|
| SECURITY.md | 34% (17/50) | HIGH | Security disclosure policy |
| CODEOWNERS | 34% (17/50) | MEDIUM | Code review ownership |
| Dependabot/Renovate | 38% (19/50) | MEDIUM | Automated dependency updates |
| FUNDING.yml | 28% (14/50) | LOW | Sustainability |

### Tier 3 — Structural Analysis (cpm should understand)

| Missing Check | Adoption | Priority | Rationale |
|---------------|----------|----------|-----------|
| Monorepo detection | 26% (13/50) | HIGH | Adjusts other checks |
| Repo-type classification | N/A | HIGH | Software vs docs/list |
| Package manager detection | N/A | MEDIUM | npm vs pnpm vs yarn |
| Linting tool detection | 54% (27/50) | MEDIUM | Code quality tooling |
| Test framework detection | N/A | MEDIUM | Better test check accuracy |
| Runtime version pinning (.nvmrc) | 14% (7/50) | LOW | Reproducibility |

### Tier 4 — Process & Automation

| Missing Check | Adoption | Priority | Rationale |
|---------------|----------|----------|-----------|
| Release automation | varies | MEDIUM | Changelog/release process |
| Conventional commits | varies | LOW | Commit message standards |
| Pre-commit hooks | 10% (5/50) | LOW | Local quality gates |
| Docker support | 16% (8/50) | LOW | Containerization |

### Tier 5 — Language-Specific Gaps

| Missing Check | Applies to | Priority |
|---------------|-----------|----------|
| tsconfig.json validation | TS repos (9/50) | MEDIUM |
| .rustfmt.toml presence | Rust repos | LOW |
| .golangci.yml presence | Go repos | LOW |
| .clang-format presence | C/C++ repos | LOW (already partial) |

## False Positive Analysis

cpm currently produces false positives on:

| Rule | False Positive Rate | Cause |
|------|-------------------|-------|
| `no-tests` | 40% (20/50) | Docs repos, monorepo packages in subdirs |
| `no-build-system` | 32% (16/50) | Docs repos, non-standard build |
| `unpinned-deps` | Debatable | Top repos intentionally use `^` |
| `no-contributing` | 40% (20/50) | Some use CONTRIBUTING in .github/ |

## Key Insights

1. **Repo-type detection is prerequisite**: Without knowing if a repo is software vs docs, many checks produce false positives.

2. **Monorepo awareness needed**: 26% of top repos are monorepos. cpm should detect `packages/`, `pnpm-workspace.yaml`, `lerna.json`, `turbo.json` and adjust checks accordingly.

3. **`unpinned-deps` is a style choice**: Top repos use `^` intentionally for libraries. Only apps should pin exact versions.

4. **SECURITY.md is undervalued**: Only 34% have it, but it's a GitHub-recommended security practice.

5. **AI agent config is fastest-growing**: 28% already have CLAUDE.md/AGENTS.md — this was 0% a year ago.

6. **Package manager fragmentation**: pnpm (8), yarn (5), npm (7) — cpm should detect and validate the chosen one.

## Decision

Implement checks in priority order:

### Phase 1 (Next release)

- Repo-type classification (software/docs/list)
- Monorepo detection
- `.editorconfig` presence
- `SECURITY.md` presence
- Issue/PR template presence

### Phase 2

- `.gitattributes` presence
- CODEOWNERS presence
- Dependabot/Renovate presence
- Package manager detection + lockfile validation
- Linting tool detection

### Phase 3

- Reduce false positives using repo-type
- `unpinned-deps` → downgrade to info for libraries
- `no-tests` → skip for docs repos
- `no-build-system` → skip for docs repos

## Consequences

- ~15 new checks to implement in `scan_checks.cpp`
- Repo-type detection as new core capability
- Maturity scoring adjustments
- False positive reduction
- Better signal-to-noise ratio in scan output
- `--learn` flag on `cpm findings` links to free books/resources per finding
- Learn resources sourced from free-programming-books (388k stars)
