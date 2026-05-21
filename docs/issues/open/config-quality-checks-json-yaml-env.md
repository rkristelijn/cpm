---
title: config quality checks — JSON schema, duplicate keys, env consistency
type: feat
created: 2026-05-21T06:56:00+00:00
labels: [feat, checks]
remote:
---

## What

33% of files in top 500 repos are config. cpm barely checks them.

Add checks for:

- JSON syntax validation (malformed JSON)
- YAML duplicate keys
- .env consistency (.env.example vs .env)
- Docker Compose schema validation
- package.json required fields beyond description/repository

## Why

Config errors cause runtime failures that are hard to debug.
Top 500 analysis shows config is the largest file category.

## Acceptance Criteria

- `cpm check` validates JSON files in project
- `cpm check` detects duplicate YAML keys
- `cpm check` compares .env.example with .env
