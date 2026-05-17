---
summary: cpm competitive positioning — where we fit, where we're unique, where we need to grow.
status: accepted
---

# ADR-022: Competitive Positioning

## Context

cpm operates in a crowded space of code quality tools. Understanding where we fit helps prioritize features and communicate value.

## Competitive Landscape (May 2026)

### Direct competitors

| Tool | Model | Languages | Strengths | Weakness vs cpm |
|------|-------|-----------|-----------|-----------------|
| **SonarQube** | Server (self-host/cloud) | 40+ | Deep SAST, quality gates, dashboards | Needs server, slow feedback, no framework patterns |
| **MegaLinter** | Docker CLI / CI | 50 langs, 22 formats | Breadth, open source | Docker required, syntax-only (no architecture patterns) |
| **CodeScene** | SaaS | Any | Behavioral analysis, hotspots, tech debt ROI | Expensive, no local-first, no framework checks |
| **pre-commit** | Python CLI | Any (via hooks) | Mature ecosystem, per-file | Hook manager only, no maturity/scoring/teaching |
| **Snyk** | SaaS + CLI | Any | CVE database, auto-fix PRs | SaaS dependency, no pattern checks |
| **Codacy** | SaaS | 40+ | Auto-review, IDE integration | $15/user/mo, no local-first |
| **CodeClimate** | SaaS | 10+ | Maintainability score, coverage | No framework awareness, SaaS lock-in |
| **Husky + lint-staged** | npm | JS/TS | Simple git hooks | Hooks only, no checks, no maturity |

### Where cpm is unique

| Differentiator | Details |
|----------------|---------|
| **Framework-aware patterns** | 80+ checks for NestJS, React, NextJS, Angular, MUI, Express, Strapi, TanStack, Apollo, Terraform, Nx — no other tool does this |
| **RTFM-based** | Checks derived from actual training material (learn.nestjs.com, Epic React, Clean Code, Accelerate) |
| **Zero dependencies** | Bash + git. No Docker, no Python, no Node required to run |
| **Local-first** | Instant feedback, works offline, no server/SaaS |
| **Learn don't police** | Every finding explains what, why, fix, docs |
| **Maturity model** | DORA metrics + ISO 25010 quality characteristics + progression levels |
| **Polyrepo scan** | 100+ repos in <1s (file-based, no clone needed) |
| **JUnit XML output** | Integrates with any CI (GitLab, GitHub Actions, Jenkins) |
| **One binary** | Install globally, use everywhere, no per-repo config needed |

### Where cpm is weaker (gaps to close)

| Gap | Who does it better | Priority | Effort |
|-----|-------------------|----------|--------|
| Deep SAST (taint analysis, data flow) | SonarQube, Semgrep Pro | Low | High (needs AST) |
| CVE database coverage | Snyk, Dependabot | Medium | Low (wrap npm audit) |
| Behavioral analysis (change hotspots) | CodeScene | Medium | Medium (git log) |
| IDE integration (real-time) | SonarLint, Codacy | Low | High |
| Dashboard/trends over time | SonarQube, CodeClimate | Medium | Medium (JSONL → HTML) |
| Auto-fix suggestions | Codacy, Snyk | Low | High |
| PR decoration (inline comments) | SonarQube, Codacy | Medium | Medium (CI integration) |

## Decision

cpm positions as:

> **The framework-aware quality layer between git and your code — local-first, zero-dep, with knowledge from real trainings baked into every check.**

We do NOT compete on:
- Deep SAST (use Semgrep/SonarQube alongside cpm)
- CVE scanning (use Snyk/Dependabot alongside cpm)
- Dashboards (use Port.io, SonarQube, or cpm's JUnit in CI)

We DO compete on:
- **Speed** — instant local feedback vs waiting for CI
- **Framework knowledge** — patterns no generic tool catches
- **Zero friction** — no server, no Docker, no config, no account
- **Teaching** — every finding is a learning moment
- **Breadth** — one tool for all your repos, all your frameworks

## Positioning statement

For developers and teams who want quality feedback before pushing, cpm is the local-first quality tool that understands your framework's best practices. Unlike SonarQube (needs a server), MegaLinter (needs Docker), or Snyk (needs an account), cpm is one binary that works instantly on any repo with zero configuration.

## Next steps (to strengthen position)

1. **PR decoration** — `cpm ci` command that posts findings as GitLab/GitHub comments
2. **Trend tracking** — JSONL findings over time, simple HTML report
3. **`cpm fix`** — auto-fix for simple findings (formatting, imports)
4. **Plugin system** — let teams add custom checks without forking
5. **VS Code extension** — real-time findings in editor (long-term)

## References

- @see docs/adrs/adr-013-product-positioning.md
- @see docs/adrs/adr-020-product-vision.md
- MegaLinter: https://megalinter.io
- CodeScene: https://codescene.com
- SonarQube: https://www.sonarsource.com
