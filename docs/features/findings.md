# cpm findings

Query the findings database produced by `cpm scan` or `cpm check`.

## Usage

```bash
cpm findings                     # all findings
cpm findings my-repo             # findings for specific repo
cpm findings --severity error    # filter by severity
cpm findings --junit             # output as JUnit XML (for CI)
```

## Output

```text
$ cpm findings legacy-service
  error    node-eol              Node.js 14 is EOL — upgrade to 20+
  warning  unpinned-deps         Dependencies use ^ or ~
  warning  typescript-eol        TypeScript 4.x is EOL — upgrade to 5+
  warning  no-contributing       No CONTRIBUTING.md
  warning  no-agent-config       No AI agent config
```

## Finding format

Each finding has:

| Field | Description |
|-------|-------------|
| severity | `error`, `warning`, `info` |
| check | which check produced it |
| message | what's wrong |
| fix | how to resolve it |

## Storage

Findings are stored as JSONL (one JSON object per line) in `.tmp/findings.jsonl`:

```json
{"repo":"legacy-service","check":"node-eol","severity":"error","message":"Node.js 14 is EOL","fix":"Upgrade to Node.js 20+"}
```

## Export formats

- Console (default) — colored, human-readable
- JUnit XML (`--junit`) — CI integration
- JSONL (raw file) — programmatic access

## Related

- [scan.md](scan.md) — produce findings from multiple repos
- [check.md](check.md) — produce findings from current repo
