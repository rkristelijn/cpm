---
summary: All checks (bash and C++) produce identical Finding records via one contract.
status: partially-implemented
---

# ADR-129: Unified Findings Contract

*Date*: 2026-05-19
*Related*: [ADR-014](adr-014-findings-database.md), [ADR-126](adr-126-traceability-by-design.md)

## Context

cpm has two check systems that evolved independently:

| System | Count | Output | Structured? |
|--------|-------|--------|-------------|
| C++ checks (`src/checks/`) | 36 | `Finding` struct (8 fields) | Yes |
| Shell checks (`checks/universal/`) | 41 | `print_error`/`print_warning` | **No** (1/41 uses `findings_add`) |

**Problems:**

1. Shell checks produce ad-hoc text — not queryable, no JUnit XML, no trend analysis
2. The `findings_add()` API exists in `lib/shell/findings.sh` but is unused by 40/41 checks
3. Fields are inconsistent: line numbers missing in 40%, fix suggestions in 60%, docs links in 100%
4. Duplicate logic: secrets, file-size, inclusivity exist in both C++ and shell
5. No single source of truth for "what did the last check run find?"

## Decision

### One contract, two implementations

Every check — regardless of language — produces `Finding` records with these fields:

```jsonl
{
  "ts": "2026-05-19T07:00:00+02:00",
  "check": "file-size",
  "severity": "error|warning|info",
  "file": "src/scan.cpp",
  "line": 0,
  "rule": "source-too-long",
  "message": "1021 lines exceeds 600 limit",
  "fix": "Split into smaller modules",
  "docs": "https://cpm.dev/checks/file-size",
  "first_seen": "abc1234",
  "first_ts": "2026-05-10T...",
  "commit": "def5678"
}
```

### Required fields

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| check | Yes | — | Check name (kebab-case) |
| severity | Yes | — | `error`, `warning`, `info` |
| file | Yes | `""` | Affected file path |
| line | No | `0` | Line number (0 = unknown) |
| rule | Yes | — | Rule ID (kebab-case) |
| message | Yes | — | Human-readable description |
| fix | Yes | `""` | How to fix (command or instruction) |
| docs | No | `""` | URL to documentation |

### Shell implementation: `lib/shell/check.sh` wrapper

```bash
#!/usr/bin/env bash
# check.sh — Standard wrapper for all shell checks.
# Source this instead of init.sh to get: set -o, findings_init, trap findings_finish.
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
CHECK_NAME="$(basename "${BASH_SOURCE[1]}" .sh)"

source "$(dirname "${BASH_SOURCE[0]}")/init.sh"
findings_init "$CHECK_NAME"
trap 'findings_finish' EXIT
```

Check scripts become:

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/../../lib/shell/check.sh"

# Only the logic — no boilerplate:
hits=$(cpm_search "$PATTERNS" src)
[[ -n "$hits" ]] && findings_add "error" "$file:$line" "hardcoded-secret" \
  "Potential API key detected" \
  "Use environment variable or secrets manager" \
  "https://cpm.dev/checks/secrets"
```

### C++ implementation: unchanged

The existing `Finding` struct in `src/checks/check.h` already matches the contract. No changes needed.

### Migration path

1. Create `lib/shell/check.sh` wrapper
2. Migrate checks in batches (security → quality → deps → docs)
3. Each migrated check: replace `print_error` with `findings_add`
4. Remove duplicate C++/shell checks (keep the one with better coverage)

### Deduplication rules

| Check | Keep | Remove | Reason |
|-------|------|--------|--------|
| secrets | C++ (faster, in-process) | Shell | Same patterns, C++ is faster |
| file-size | Shell (configurable) | — | C++ version is scan-only |
| inclusivity | Shell (more patterns) | C++ (subset) | Shell has richer patterns |
| pii | Shell (regex-based) | C++ (subset) | Shell is more complete |

### Output destinations

```text
findings_add() → .tmp/findings.jsonl   (append, queryable)
              → .tmp/junit.xml         (generated at findings_finish)
              → console                (colored, human-readable)
```

## Consequences

### Positive

- One queryable findings database regardless of check language
- JUnit XML for any CI system
- Trend analysis over time (first_seen tracking)
- Consistent output: every finding has what, why, fix
- Boilerplate eliminated from 41 shell scripts
- `cpm findings` works for all checks

### Negative

- Migration effort: 40 shell checks need updating
- Slight overhead: JSONL append per finding (negligible)
- Shell checks become dependent on findings.sh (already sourced via init.sh)

## Acceptance Criteria

- [ ] All shell checks use `findings_add` (0 uses of bare `print_error` for findings)
- [ ] `cpm findings` returns results from both C++ and shell checks
- [ ] Every finding has: check, severity, file, rule, message, fix (6 required fields)
- [ ] JUnit XML generated for all check runs
- [ ] `lib/shell/check.sh` wrapper exists and is sourced by all checks

## References

- @see docs/adrs/adr-014-findings-database.md (JSONL format)
- @see docs/adrs/adr-126-traceability-by-design.md (traceability)
- @see docs/adrs/adr-127-traceability-scope.md (ISO 9126 mapping)
- @see lib/shell/findings.sh (existing API)
- @see src/checks/check.h (C++ Finding struct)
