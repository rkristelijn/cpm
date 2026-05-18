# cpm scan

Scan multiple repositories for quality metrics. File-based, no tools needed, runs in <1s for 100+ repos.

## Usage

```bash
cpm scan ~/git/hub              # scan all repos in directory
cpm scan ~/git/hub --depth 2    # recurse 2 levels deep
cpm scan .                      # scan current repo
```

## Output

```text
$ cpm scan ~/git/hub --depth 1

  Scanning (depth 1)...
  Found 12 repos

  [1/12] my-api                              0 findings
  [2/12] my-frontend                         3 findings
  [3/12] legacy-service                      7 findings
  ...

  Scan Report (12 repos)
  ─────────────────────────────────────────────
  Errors: 4 | Warnings: 18
```

## What it checks (file-based)

No tools are executed — cpm reads files directly for speed:

- Node.js/TypeScript EOL versions
- Unpinned dependencies (`^` or `~` in package.json)
- Missing CONTRIBUTING.md
- Missing AI agent config (.kiro/, .amazonq/)
- Lockfile presence
- License detection
- Framework detection (React, Next.js, NestJS, Angular, etc.)

## Findings database

Results are stored in `.tmp/findings.jsonl` for querying:

```bash
cpm findings my-api              # show findings for a repo
cpm findings --severity error    # filter by severity
```

## Performance

- Target: 100+ repos in <1s
- Implementation: pure file I/O (no `system()` calls)
- Language detection via file presence (package.json, Cargo.toml, etc.)

## Related

- [findings.md](findings.md) — query and filter findings
