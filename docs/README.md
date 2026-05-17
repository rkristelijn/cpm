# cpm Documentation

## Quick Start
- [ARCHITECTURE.md](ARCHITECTURE.md) — Auto-generated technical overview (re-run `bash scripts/generate-docs.sh .`)
- [../CONTRIBUTING.md](../CONTRIBUTING.md) — How to contribute
- [../CHANGELOG.md](../CHANGELOG.md) — What changed

## Design
- [v-model.md](v-model.md) — V-model: choose your depth
- [design-patterns.md](design-patterns.md) — Patterns & principles reference
- [CONVENTIONS.md](CONVENTIONS.md) — Coding conventions

## Architecture Decisions (ADRs)
Key decisions documented in [adrs/](adrs/):
- [ADR-013](adrs/adr-013-product-positioning.md) — Product positioning & philosophy
- [ADR-014](adrs/adr-014-findings-database.md) — Findings database (JSONL)
- [ADR-017](adrs/adr-017-polyrepo-scan.md) — Polyrepo scan
- [ADR-020](adrs/adr-020-product-vision.md) — Product vision

## Features
- [features/](features/) — GIF demos of cpm commands

## Regenerate docs
```bash
bash scripts/generate-docs.sh . > docs/ARCHITECTURE.md
```
