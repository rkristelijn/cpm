# cpm xref

Validate cross-references between code and documentation.

## Usage

```bash
cpm xref
```

## What it checks

- `@see` annotations in source code point to existing files
- ADR references in docs point to existing ADRs
- Broken internal links between documents

## Why

Traceability — every decision (ADR) should link to code, every code file should link to its design decision. When files move or get deleted, xref catches the broken links.

## See also

- `cpm todo` — track TODO/FIXME items
- Traceability coverage: `checks/universal/quality/check-traceability-coverage.sh`
