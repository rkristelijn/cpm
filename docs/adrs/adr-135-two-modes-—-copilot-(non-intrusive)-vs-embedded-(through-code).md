---
summary: cpm operates in two modes — copilot (all in .cpm/) or embedded (@see, findings in code).
status: proposed
---

# ADR-135: Two Modes — Copilot vs Embedded

*Date*: 2026-05-19

## Decision

### Copilot Mode (non-intrusive)

Everything lives in `.cpm/`. Zero changes to your code.

```
.cpm/
├── findings.jsonl
├── phase.log
├── traceability.json
├── maturity.json
└── config.toml
```

Your code stays clean. cpm observes, reports, guides — but never touches source files.

### Embedded Mode (through code)

cpm annotations live IN the code: `@see`, `@trace`, `cpm:ignore`, `cpm:exempt`.

```cpp
// @see ADR-129
// @trace feature:scan
void scan() { ... } // cpm:ignore complexity
```

Richer traceability, but intrusive.

### Choosing

```toml
# cpm.toml
[mode]
style = "copilot"  # copilot | embedded
```

## Vision

With all process steps guarded, integrity checks at every gate, and steps small enough for any LLM — cpm becomes a **verified development pipeline** where quality is guaranteed by process, not by intelligence.

## Enforcement

| What | How | Automation |
|------|-----|-----------|
| Mode respected | Checks read `[mode]` from cpm.toml | `cpm check` adapts |
| Copilot: no code annotations required | Skip @see checks | Config-driven |
| Embedded: annotations enforced | check-xref, check-stale-docs | Existing checks |

## References

- @see ADR-020 (product vision)
- @see ADR-013 (product positioning)
