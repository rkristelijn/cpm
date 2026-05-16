---
summary: cpm product vision — one binary, zero friction, all quality, any language, any level.
status: accepted
---

# ADR-020: Product Vision — The Missing Link

## One sentence

cpm is the missing link between your code and quality — one binary that makes compliance, maturity, and best practices accessible to everyone.

## The problem

- Git doesn't care about quality
- CI is too late (shift-right)
- Sonar needs a server
- Linters are per-language, per-tool, per-config
- Juniors don't know what to check
- Seniors don't have time to enforce
- AI generates code without guardrails
- Every repo reinvents the wheel

## The solution

One binary. Globally installed. Zero friction bolt-on.

```bash
brew install cpm    # or: curl ... | bash
cd any-repo
cpm check           # instant quality feedback
cpm maturity        # where do I stand?
cpm scan ~/repos    # organization-wide health
```

## Core principles

### 1. One binary, 100 applications

No shell scripts to commit. No lib/ to copy. Install globally, use everywhere.

```text
cpm check       — run quality checks
cpm scan        — polyrepo health scan
cpm maturity    — maturity level audit
cpm init        — bootstrap a repo
cpm index       — term/concept map
cpm trace       — traceability matrix
cpm findings    — query findings database
cpm demo        — showcase UI
```

### 2. Zero friction bolt-on

Works without config. Works without committing anything. Just run it.

```text
No cpm.toml?     → sensible defaults
No Makefile?     → cpm runs checks directly
No tools?        → skip gracefully, suggest install
No CI?           → works locally, suggests pipeline
```

### 3. Your config, your rules

Everything is overridable:

```text
Default doxygen config not right?  → put yours in .config/Doxyfile
Want to skip a check?              → cpm.toml [skip] or inline annotation
Custom tool?                       → add to Makefile, cpm sees it
Different maturity definition?     → cpm.toml [maturity.levels]
Own severity mapping?              → cpm.toml [severity]
```

### 4. Encapsulates best-of-breed tools

cpm doesn't replace tools — it orchestrates them:

| Tool | What cpm does |
|------|--------------|
| gitleaks | Runs it, parses output, maps to findings DB |
| semgrep | Runs it, maps rules to severity |
| clang-format | Runs it, reports diff as finding |
| eslint/biome | Detects which exists, runs it |
| npm audit | Parses JSON output, maps CVEs to findings |
| doxygen | Runs it, counts warnings |

Config files managed by cpm (in `.config/` or root, your choice).

### 5. Super fast OR super thorough (your choice)

```text
cpm check fast      — file-based only, <1s
cpm check           — tools run, <60s
cpm check full      — everything, minutes
cpm scan            — 100+ repos in <1s (file-based)
```

### 6. Shift left, fail smart, fail at YOUR level

```toml
# cpm.toml
[enforcement]
level = "guide"    # learn | guide | guard | enforce

[maturity]
target = 2         # don't enforce level 3 checks yet
```

Level 1 project? Only level 1 checks block. Growing to level 3? Checks unlock gradually. No all-or-nothing.

### 7. V-model dimensionality

Projects grow in process maturity:

```text
1D: Just build (code → ship)
2D: V-model (motivate → design → code → test → verify)
3D: Tailored V per workflow:
    - Bugfix:    reproduce → fix → verify → push
    - Feature:   ADR → design → implement → test → review
    - Refactor:  measure → change → verify no regression
    - P1:        hotfix → deploy → postmortem
```

cpm adapts its checks to the workflow:

```bash
cpm check --workflow bugfix     # minimal: build + test + no regression
cpm check --workflow feature    # full: ADR exists + tests + docs
cpm check --workflow refactor   # measure before/after
```

### 8. AI-ready, AI-streamlined

- CONTRIBUTING.md = agent instructions
- Agent config (.kiro/, .amazonq/, .cursorrules)
- Slop detection (AI-generated anti-patterns)
- Findings as context for AI (fix suggestions)
- `cpm init` generates AI-ready boilerplate

### 9. Reports everywhere

```text
Console     — live, colored, spinners, timing
JUnit XML   — CI integration (any platform)
JSONL       — queryable findings database
CSV         — spreadsheet export
Webhook     — push to Jira, ClickUp, Vanta, Port
Badge       — shields.io compatible
```

### 10. Learn, don't police

Every finding has:
- **What**: the violation
- **Why**: motivation (link to standard/ADR)
- **Fix**: exact command to resolve
- **Skip**: how to opt out if you disagree
- **Docs**: link to learn more

## Architecture (target state)

```text
┌─────────────────────────────────────────────┐
│              cpm binary (C++)               │
├─────────────────────────────────────────────┤
│ Commands: check, scan, maturity, init, ...  │
├─────────────────────────────────────────────┤
│ Core:                                       │
│   - TOML parser (config)                    │
│   - Findings DB (JSONL read/write)          │
│   - JUnit renderer                         │
│   - Term indexer                           │
│   - Repo discovery (scan)                  │
│   - Language detection                     │
│   - Maturity scoring                       │
├─────────────────────────────────────────────┤
│ Check runners:                              │
│   - File-based (fast, in-process)          │
│   - Tool-based (shell out to gitleaks etc) │
├─────────────────────────────────────────────┤
│ Config resolution:                          │
│   project cpm.toml → global → defaults     │
└─────────────────────────────────────────────┘
```

## What cpm is NOT

- Not a build system (use make/cmake/cargo/npm)
- Not a CI system (use GitHub Actions/GitLab CI)
- Not a linter (it orchestrates linters)
- Not Sonar (no server, no dashboard, local-first)
- Not political (shift-left is about speed, not ideology)

## Success metrics

- Install to first check: < 30 seconds
- Scan 100 repos: < 1 second
- Single repo check (fast): < 5 seconds
- Single repo check (full): < 60 seconds
- Zero false positives at level 1
- Every finding has a fix command

## References

- @see docs/adrs/adr-013-product-positioning.md (framework foundation)
- @see docs/adrs/adr-017-polyrepo-scan.md (scan architecture)
- @see docs/adrs/adr-014-findings-database.md (JSONL format)
- @see docs/adrs/adr-018-language-framework-scoring.md (scoring)
- @see docs/adrs/adr-010-resolution-strategy.md (config resolution)
