# cpm check

Run quality gates with tiered depth.

## Usage

```bash
cpm check --fast   # pre-commit: format + build (<5s)
cpm check          # pre-push: + lint + test (<60s)
cpm check --full   # CI: + coverage + SAST (minutes)
```

## Tiers

| Tier | When | What runs |
|------|------|-----------|
| `--fast` | pre-commit | format, build |
| (default) | pre-push | + lint, test, complexity, secrets |
| `--full` | CI | + coverage, SAST, docs, all checks |

## How it works

1. Reads `cpm.toml` for enabled checks
2. Detects build system (Makefile > CMake > raw compiler)
3. Runs checks in parallel where possible
4. Reports findings with timing

## Check categories

| Category | Examples |
|----------|---------|
| Security | secrets, PII, SAST, SBOM |
| Quality | file size, complexity, comments, slop, duplication |
| Deps | lockfile, version pins, licenses, runtime EOL |
| Docs | dead docs, inclusivity, web essentials |
| Architecture | portability, Makefile, unicode |

## Configuration

```toml
# cpm.toml — enable/disable individual checks
[checks]
code-cpp-syntax-format = true
code-generic-secrets-scan = true
code-cpp-complexity-measure = true

[checks.code-cpp-complexity-measure]
threshold = 10
```

## Exit codes

- `0` — all checks pass
- `1` — one or more checks failed

## Related

- [enforcement-levels.md](enforcement-levels.md) — control blocking behavior
- [hooks.md](hooks.md) — auto-run checks on commit/push
