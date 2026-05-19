---
summary: cpm discover uses a cached index for fast incremental repo analysis — scan once, query many.
status: proposed
---

# ADR-133: Discover Architecture — Cached Incremental Repo Analysis

*Date*: 2026-05-19
*Related*: [ADR-017](adr-017-polyrepo-scan.md), [ADR-020](adr-020-product-vision.md)

## Context

`cpm discover` is too slow on large repos (>1000 files). The current approach runs grep/find per-pass, scanning the entire repo multiple times. A 10k-file repo takes minutes — unacceptable.

## Decision

### Two-phase architecture

```text
Phase 1: Index (once, cached)
  git ls-files → .tmp/discover-index.json
  Contains: file list, extensions, package.json deps, config files found
  Time budget: <2s for any repo

Phase 2: Analyze (instant, from cache)
  Read index → detect patterns → report
  Time budget: <100ms
```

### Index format (.tmp/discover-index.json)

```json
{
  "ts": "2026-05-19T09:00:00",
  "commit": "abc1234",
  "files": 4521,
  "extensions": {"ts": 200, "js": 150, "json": 40},
  "deps": {"react": "18.2.0", "next": "14.0.0"},
  "devDeps": {"jest": "29.0.0", "eslint": "8.0.0"},
  "configs": [".prettierrc", "tsconfig.json", "Dockerfile"],
  "dirs": ["src", "test", "docs", "scripts"],
  "entry_points": ["src/index.ts"],
  "has": {"tests": true, "ci": true, "docker": true, "adrs": false}
}
```

### Incremental updates

- Re-index only when `git rev-parse HEAD` differs from cached commit
- Or when `--force` flag passed
- Delta: only scan changed files since last index

### Analysis passes (all from cache, no I/O)

| Pass | Source | Time |
|------|--------|------|
| Structure | extensions, files count | <1ms |
| Frameworks | deps + devDeps | <1ms |
| Toolchain | configs + devDeps | <1ms |
| Architecture | dirs + entry_points | <1ms |
| Decisions | deps + configs (pattern match) | <1ms |
| Traceability | Requires grep (deferred/sampled) | <500ms |

### Traceability: sampling approach

Full grep for `@see` is expensive. Instead:
- Sample 50 random source files
- Extrapolate coverage %
- Full scan only on `--full` flag

### AI validation (future)

After analysis, optionally pass the index to an AI for:
- Architecture pattern recognition
- Inconsistency detection
- ADR suggestions with rationale

## Enforcement

| What | How | Automation |
|------|-----|-----------|
| Index <2s | Timing assertion in test | E2E test |
| Analysis <100ms | Timing assertion | E2E test |
| Cache invalidation | Compare HEAD commit | Automatic |

## Consequences

### Positive
- Any repo discoverable in <3s total
- Repeated queries instant (from cache)
- Incremental — only re-scans on changes
- Foundation for AI-assisted analysis

### Negative
- Cache can be stale (mitigated by commit check)
- Index format is another thing to maintain
- Sampling traceability is approximate

## References

- @see lib/shell/discover.sh (current prototype)
- @see ADR-017 (polyrepo scan — same <1s philosophy)
