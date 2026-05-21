---
title: scan report — language distribution, file composition, activity breakdown
type: feat
created: 2026-05-21T06:56:00+00:00
labels: [feat, scan]
remote:
---

## What

`cpm scan` should report richer metrics beyond findings:

- Language distribution (how many repos per language)
- File composition (% docs / code / config)
- Activity breakdown (active / recent / stale)
- Repo size distribution

## Why

Currently we need custom python scripts to extract this data from scanned repos.
cpm should provide this natively via `cpm scan --report` or in the default output.

## Acceptance Criteria

- `cpm scan <path>` shows language distribution
- `cpm scan <path>` shows activity breakdown
- `cpm scan --report` generates full markdown report with all metrics
