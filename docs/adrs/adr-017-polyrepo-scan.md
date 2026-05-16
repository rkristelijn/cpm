---
summary: cpm scan — discover repos, detect language, run checks, aggregate findings across polyrepo.
status: accepted
---

# ADR-017: Polyrepo Scan (cpm scan)

## Context

We have 100+ repos across multiple directories. Running quality checks manually per repo doesn't scale. We need one command that scans all repos, detects their language, runs appropriate checks, and aggregates findings.

## Decision

### Command interface

```bash
cpm scan <path>                    # scan all repos under path
cpm scan <path> --lang ts          # filter by language
cpm scan <path> --lang cpp,ts      # multiple languages
cpm scan <path> --check npm-audit  # specific check only
cpm scan <path> --depth 3          # max directory depth (default: 3)
cpm scan --report                  # show aggregated report from last scan
cpm scan --report --severity error # filter report
```

### Architecture (C++ binary)

```text
src/
├── scan/
│   ├── scan.h           # scan command interface
│   ├── scan.cpp         # orchestrator
│   ├── discover.h       # repo discovery (find .git dirs)
│   ├── discover.cpp     # parallel directory walk
│   ├── detect.h         # language detection
│   ├── detect.cpp       # detect from files (package.json, CMakeLists, etc.)
│   └── report.cpp       # aggregate findings, render report
```

### Repo discovery

Walk directory tree, find `.git` directories (max depth configurable):

```cpp
struct Repo {
    std::string path;
    std::string name;
    std::vector<std::string> languages;  // detected from files
    bool has_cpm_toml;
};
```

### Language detection (from lcode patterns)

| File present | Language |
|-------------|----------|
| `package.json` | typescript/javascript |
| `tsconfig.json` | typescript |
| `CMakeLists.txt` | cpp |
| `Makefile` + `src/*.cpp` | cpp |
| `Cargo.toml` | rust |
| `pyproject.toml` / `requirements.txt` | python |
| `pom.xml` / `build.gradle` | java |
| `composer.json` | php |
| `go.mod` | go |

### Check execution

For each repo:
1. `cd` into repo
2. Detect language
3. Select checks (universal + language-specific)
4. Run checks (shell scripts via `system()` or `popen()`)
5. Findings written to `<repo>/.tmp/findings.jsonl`

### Aggregated report

```text
$ cpm scan <repos-dir> --report

  Polyrepo Scan Report (104 repos)
  ─────────────────────────────────────────────
  Languages: ts(42) java(28) php(12) cpp(8) other(14)

  Top findings:
    48 repos: unpinned dependencies
    31 repos: no test script in package.json
    22 repos: npm audit vulnerabilities
    15 repos: missing LICENSE
     8 repos: secrets detected

  By severity:
    errors: 156 (across 52 repos)
    warnings: 423 (across 89 repos)
    info: 67

  Worst repos:
    supplier-manager       23 errors
    media-publisher        18 errors
    allocation-manager     12 errors
```

### Traceability integration (ADR-016)

Scan results link back to:
- Which check produced the finding
- Which ADR documents the rule
- When it was first detected (first_seen in JSONL)
- Which commit introduced it

```bash
cpm scan --report --trace feature:security
# Shows only security-related findings across all repos
```

### Performance

- Parallel repo discovery (std::filesystem, multi-threaded)
- Checks run sequentially per repo (avoid resource contention)
- Results cached per repo (skip if no git changes since last scan)
- Target: 100 repos in < 60 seconds

### Output formats

```bash
cpm scan <repos-dir>                     # terminal (live progress)
cpm scan <repos-dir> --output json       # JSON report
cpm scan <repos-dir> --output csv        # CSV export
cpm scan <repos-dir> --output junit      # aggregated JUnit XML
```

## Implementation plan

1. Add `scan` subcommand to cpm binary
2. Implement repo discovery (parallel directory walk)
3. Implement language detection
4. Shell out to check scripts per repo
5. Aggregate findings from all `.tmp/findings.jsonl` files
6. Render report

## Consequences

- One command to assess quality across 100+ repos
- Language-aware: right checks for right repos
- Findings stored per-repo (not centralized — each repo owns its data)
- Aggregated report shows organization-wide health
- No code modification needed in target repos

## References

- @see docs/adrs/adr-014-findings-database.md (JSONL format)
- @see docs/adrs/adr-015-typescript-plugin.md (TS checks)
- @see docs/adrs/adr-016-traceability-matrix.md (trace integration)
- @see lcode (repo discovery inspiration: github.com/rkristelijn/lcode)
