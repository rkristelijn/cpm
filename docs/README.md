# cpm Documentation

## Features

| Article | Description |
|---------|-------------|
| [init](features/init.md) | Bootstrap a project with `cpm init` |
| [check](features/check.md) | Quality gates (`--fast`, default, `--full`) |
| [scan](features/scan.md) | Polyrepo scanning (100+ repos in <1s) |
| [findings](features/findings.md) | Query findings database |
| [new](features/new.md) | Scaffold projects, tests, modules |
| [commit](features/commit.md) | Interactive conventional commit |
| [issue](features/issues.md) | Local-first issue tracking (push/pull) |
| [hooks](features/hooks.md) | Git hooks (pre-commit, pre-push) |
| [eject](features/eject.md) | Generate Makefile / CMakeLists.txt |
| [config](features/config.md) | cpm.toml configuration (`get` / `set`) |
| [enforcement-levels](features/enforcement-levels.md) | learn / guide / guard / enforce |
| [maturity](features/maturity.md) | Maturity levels (0–4) |
| [pii-detection](features/pii-detection.md) | PII scanning & `.piiignore` |
| [secrets](features/secrets.md) | Secret detection (API keys, tokens) |

## Architecture

- [ARCHITECTURE.md](ARCHITECTURE.md) — Auto-generated technical overview
- [v-model.md](v-model.md) — V-model: choose your depth
- [design-patterns.md](design-patterns.md) — Patterns & principles reference
- [CONVENTIONS.md](CONVENTIONS.md) — Coding conventions

## ADRs

Key decisions documented in [adrs/](adrs/):

- [ADR-013](adrs/adr-013-product-positioning.md) — Product positioning & philosophy
- [ADR-014](adrs/adr-014-findings-database.md) — Findings database (JSONL)
- [ADR-017](adrs/adr-017-polyrepo-scan.md) — Polyrepo scan
- [ADR-020](adrs/adr-020-product-vision.md) — Product vision
- [ADR-169](adrs/adr-169-smart-init.md) — Smart init: idempotent config with rule relevance detection

## Audits

- [AI Slop Audit](audits/ai-slop-audit.md) — Code quality assessment: real vs AI-generated patterns
- [lib/shell audit](audits/lib-shell-audit.md) — Shell library quality review

## Contributing

- [../CONTRIBUTING.md](../CONTRIBUTING.md) — How to contribute
- [../CHANGELOG.md](../CHANGELOG.md) — What changed

## Regenerate docs

```bash
bash scripts/generate-docs.sh . > docs/architecture.md
```
