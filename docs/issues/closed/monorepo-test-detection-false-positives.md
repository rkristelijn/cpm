---
title: monorepo test detection — scan packages/ subdirs for tests
type: fix
created: 2026-05-21T06:56:00+00:00
labels: [fix, scan]
remote:
---

## What

`no-tests` has 29% false positive rate on top 500 repos because monorepos
have tests inside packages/ subdirs, not at root level.

## Fix

When monorepo detected (packages/, pnpm-workspace, turbo.json, nx.json):

- Scan each package subdir for test files
- Only flag `no-tests` if NO package has tests

## Acceptance Criteria

- `cpm scan` on next.js (monorepo) does NOT flag no-tests
- `cpm scan` on a monorepo with 0 tests in any package DOES flag
