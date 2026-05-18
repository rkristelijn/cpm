---
summary: Local findings database (JSONL) tracks all violations with first-seen commit, enables push to any target.
status: accepted
---

# ADR-014: Findings Database & Multi-Target Output

## Context

cpm checks produce findings (violations, warnings, suggestions). Currently they're printed to console and lost. We need:

- Track when a finding first appeared (which commit)
- Know if it's new or existing tech debt
- Push findings to multiple targets (console, JUnit, GitHub Issues, Jira, ClickUp, Vanta, Port)
- Query history (is this getting better or worse?)

## Decision

### JSONL as local findings database

`.tmp/findings.jsonl` — append-only, one finding per line:

```jsonl
{"ts":"2026-05-16T08:45:00+0200","check":"npm-audit","severity":"error","file":"package.json","line":0,"rule":"CVE-2024-1234","message":"lodash <4.17.21 has prototype pollution","fix":"npm update lodash","docs":"https://nvd.nist.gov/vuln/detail/CVE-2024-1234","first_seen":"abc1234","first_ts":"2026-05-10T12:00:00+0200","commit":"def5678"}
```

### Finding schema

| Field | Type | Description |
|-------|------|-------------|
| `ts` | ISO8601 | When this check ran |
| `check` | string | Check name (e.g. `npm-audit`, `check-complexity`) |
| `severity` | enum | `error`, `warning`, `info` |
| `file` | string | File path (relative to repo root) |
| `line` | int | Line number (0 if not applicable) |
| `rule` | string | Rule/CVE/code identifier |
| `message` | string | Human-readable description |
| `fix` | string | Exact command or action to fix |
| `docs` | string | URL to documentation/explanation |
| `first_seen` | string | Git commit hash when first detected |
| `first_ts` | ISO8601 | Timestamp of first detection |
| `commit` | string | Current commit hash |

### Why JSONL

| Option | Pros | Cons |
|--------|------|------|
| **JSONL** (chosen) | Append-only, streamable, jq/grep/awk parseable, no deps | No indexing |
| SQLite | Queryable, indexed | Binary, needs sqlite3 |
| CSV | Simple | Escaping hell, no nested data |
| NoSQL (LevelDB) | Fast queries | Binary dep, overkill |

JSONL wins: zero deps, append-only (no corruption), one `grep` to query, `jq` for complex queries. Good enough for thousands of findings per repo.

### First-seen tracking

When a finding is detected:

1. Check if same `check + file + rule` exists in findings.jsonl
2. If yes → reuse `first_seen` and `first_ts` (it's existing debt)
3. If no → set `first_seen` to current commit (it's new)

This enables: "this vulnerability was introduced in commit abc1234, 6 days ago"

### Multi-target output (push providers)

Findings are stored locally. Then pushed to targets on demand:

```bash
cpm push console          # pretty-print to terminal (default)
cpm push junit            # .tmp/reports/cpm-junit.xml
cpm push github-issues    # create/update GitHub issues
cpm push jira             # create Jira tickets
cpm push clickup          # create ClickUp tasks
cpm push vanta            # push to Vanta compliance
cpm push port             # push to Port.io catalog
cpm push csv              # export as CSV
```

Each push target is a provider script:

```text
lib/shell/push/
├── console.sh      ← terminal output (built-in)
├── junit.sh        ← JUnit XML (built-in)
├── github.sh       ← GitHub Issues API
├── jira.sh         ← Jira REST API
├── clickup.sh      ← ClickUp API
├── vanta.sh        ← Vanta API
├── port.sh         ← Port.io API
├── csv.sh          ← CSV export
└── webhook.sh      ← Generic webhook (any target)
```

Configuration:

```toml
# cpm.toml
[push]
targets = ["console", "junit"]          # default: local only
# targets = ["console", "junit", "github-issues"]  # also create issues

[push.github]
labels = ["cpm", "auto-detected"]
assignee = ""                           # empty = unassigned

[push.jira]
project = "QCA"
issue-type = "Bug"

[push.clickup]
list-id = "123456789012"
```

### Deduplication

Before pushing to an external target:

1. Check if finding already has an issue (stored in `.tmp/findings-issues.jsonl`)
2. If yes → update/comment, don't create duplicate
3. If no → create new, store mapping

```jsonl
{"finding_hash":"abc123","target":"github","issue_id":"#42","created":"2026-05-16"}
```

### Query interface

```bash
cpm findings                    # show all current findings
cpm findings --new              # only findings from this commit
cpm findings --severity error   # only errors
cpm findings --check npm-audit  # filter by check
cpm findings --since 7d         # last 7 days
cpm findings --trend            # getting better or worse?
```

## Consequences

- Every finding is tracked with provenance (when, where, which commit)
- New vs existing debt is distinguishable
- Push to any target without changing checks
- History enables trend analysis ("are we improving?")
- Zero deps (JSONL + bash + jq for advanced queries)

## References

- @see lib/shell/findings.sh (implementation)
- @see docs/adrs/adr-013-product-positioning.md (multi-target output layer)
- @see docs/adrs/adr-012-maturity-framework-research.md (what to check)
