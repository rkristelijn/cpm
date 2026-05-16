---
summary: Bidirectional traceability via annotations — link code, docs, tests, config, and ADRs with staleness detection.
status: proposed
---

# ADR-016: Traceability Matrix

## Context

Code, docs, tests, and ADRs drift apart. A feature is implemented but the ADR is never updated. A test covers a function that was refactored. Documentation describes behavior that no longer exists. There's no way to ask: "show me everything related to the logging feature."

## Decision

### Annotation-based traceability

Every artifact (code, doc, test, config) can declare what it relates to via a `@trace` annotation:

```cpp
// @trace feature:logging, adr:027, test:test_logger
void log_event(const Event& e) { ... }
```

```markdown
<!-- @trace feature:logging, code:src/logging/logger.cpp -->
# ADR-027: Event Logging
```

```bash
# @trace feature:logging, adr:027
SCENARIO("logger: writes events to jsonl") { ... }
```

```yaml
# @trace feature:logging
LLAMA_LOG_FILE: .tmp/events.jsonl
```

### Trace format

```
@trace <type>:<id> [, <type>:<id> ...]
```

Types:
| Type | Points to | Example |
|------|-----------|---------|
| `feature` | Feature name (free text) | `feature:logging` |
| `adr` | ADR number | `adr:027` |
| `code` | Source file path | `code:src/logging/logger.cpp` |
| `test` | Test file or scenario | `test:test_logger` |
| `config` | Config key or file | `config:.env:LLAMA_LOG_FILE` |
| `issue` | Issue number | `issue:#42` |
| `req` | Requirement ID | `req:SEC-001` |

### What cpm tracks per trace

```jsonl
{"file":"src/logging/logger.cpp","line":12,"traces":["feature:logging","adr:027","test:test_logger"],"last_modified":"2026-05-10","commit":"abc1234"}
{"file":"docs/adrs/adr-027-event-logging.md","line":1,"traces":["feature:logging","code:src/logging/logger.cpp"],"last_modified":"2026-04-15","commit":"def5678"}
```

### Staleness detection

If code was modified after its linked doc/test:

```text
$ cpm trace --stale

  ⚠ Stale traces:
  src/logging/logger.cpp (modified 2026-05-10)
    → docs/adrs/adr-027-event-logging.md (last modified 2026-04-15, 25 days behind)
    → src/logging/logger_test.cpp (last modified 2026-04-20, 20 days behind)

  Suggestion: review and update linked artifacts
```

### Feature fishing ("hengeltje uitgooien")

Query everything related to a feature:

```text
$ cpm trace feature:logging

  Feature: logging
  ─────────────────────────────────
  ADR:    docs/adrs/adr-027-event-logging.md
  Code:   src/logging/logger.cpp
          src/logging/logger.h
  Tests:  src/logging/logger_test.cpp
  Config: .env (LLAMA_LOG_FILE)
          cpm.toml (checks.event-logging)
  ─────────────────────────────────
  Last change: 2026-05-10 (src/logging/logger.cpp)
  Coverage: 4/5 artifacts up to date
```

### Reports

```bash
cpm trace --orphans        # code without any @trace (unlinked)
cpm trace --stale          # linked artifacts that drifted apart
cpm trace --coverage       # % of code that has traceability
cpm trace feature:X        # everything related to feature X
cpm trace adr:027          # everything linked to ADR-027
```

### How it works

1. `cpm trace --scan` — grep all files for `@trace` annotations
2. Build a graph: file → traces → linked files
3. For each link, compare `git log -1 --format=%aI <file>` timestamps
4. Report staleness when linked artifacts are out of sync

### Maturity progression

| Level | Traceability |
|-------|-------------|
| 0 | No traces |
| 1 | ADRs exist but not linked to code |
| 2 | `@trace` in key files, `cpm trace --orphans` < 50% |
| 3 | All features traceable, staleness < 14 days |
| 4 | Auto-generated trace reports, CI blocks stale links |

### Integration with findings.sh

```bash
findings_init "check-traceability"
findings_add "warning" "src/logging/logger.cpp" "stale-link" \
  "Linked ADR-027 is 25 days behind code changes" \
  "Review and update docs/adrs/adr-027-event-logging.md"
findings_finish
```

## Consequences

- Every piece of code can be traced to its motivation (ADR), verification (test), and config
- Stale documentation is automatically detected
- "Show me everything about feature X" is one command
- Orphaned code (no trace) is visible — potential dead code or missing docs
- Lightweight: just grep for `@trace` annotations, no database needed

## References

- @see docs/adrs/adr-014-findings-database.md (findings storage)
- @see docs/adrs/adr-013-product-positioning.md (ISO 25010: Maintainability)
