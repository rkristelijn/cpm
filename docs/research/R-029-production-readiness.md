# Research: cpm Production Readiness — Honest Assessment & Roadmap

**Date:** 2026-08-28
**Status:** Research

## Current State (Honest)

### What cpm is
- 402KB static binary, zero runtime dependencies (libc++ only)
- 39 native C++ checks compiled into binary (8 deprecated → rule migration)
- 188 shell checks (require bash, run via `cpm check`)
- 875 rule files (require separate `rule-scan` binary + RE2 library)
- 14 external tool dependencies for full `cpm check` (clang-format, shellcheck, etc.)
- 0 stars, 0 forks, 0 downloads

### What works
- `cpm check --fast` — format + build, <1s, zero tool deps beyond compiler
- `cpm scan` + `cpm findings` — repo quality scan with JSONL output
- `cpm score` — maturity score (97/100 on itself)
- `cpm init` — scaffolding with sensible defaults
- `rule-scan` — 875 declarative rules, single-pass, <1s scan

### What doesn't work
- `rule-scan` is NOT integrated into `cpm check` (the most powerful checks are unreachable)
- `cpm check` fails on 11/63 checks due to missing tools (not installed by `cpm install`)
- Shell checks are untested individually (only via e2e)
- 110 shallow test assertions (SLOP-100 findings on itself)
- `scan_checks.cpp` is a 1092-line monolith
- Rules never validated on real-world projects outside cpm/cpm-eval

## The Core Architecture Decision

The fundamental question: **should the rule engine be in the main binary?**

### Option A: Merge rule-scan into cpm (add RE2 dependency)

| Pro | Con |
|-----|-----|
| One binary, one command | Binary grows from 402KB to ~2MB |
| `cpm check` includes all 875 rules | RE2 must be installed on every platform |
| Zero confusion about what's available | "One binary, zero deps" claim is broken |
| Matches user expectation | Build complexity increases |

### Option B: Keep separate, wire them together

| Pro | Con |
|-----|-----|
| Main binary stays 402KB, zero deps | Two binaries to distribute |
| RE2 optional (only if you want rules) | `cpm check` still doesn't run rules unless both installed |
| Gradual migration path | Confusing for new users |

### Option C: Embed rule engine WITHOUT RE2 (std::regex or custom matcher)

| Pro | Con |
|-----|-----|
| One binary, zero deps (for real) | std::regex has catastrophic backtracking |
| Simplest user experience | Performance 10-100x slower than RE2 |
| Cross-platform trivially | Can't handle 875 rules in <1s |

### Recommendation: Option A with static linking

Static-link RE2 into the binary. Binary grows to ~2MB but stays a single file with zero runtime deps. RE2 is MIT licensed. The "one binary" promise is kept. This is what ripgrep does with its regex engine.

## Roadmap to Production Grade

### Phase 0: Clean up (1-2 weeks)

Before adding features, fix what's broken:

1. **Fix 110 shallow test assertions** — the SLOP-100 findings on our own code
2. **Delete 8 deprecated native checks** — they have rule equivalents
3. **Split scan_checks.cpp** — decompose the 1092-line monolith into functions
4. **Add strict mode to 62 shell scripts** — the SH-STRICT-002 findings
5. **Validate rules on 5 real-world repos** — not just cpm and cpm-eval

### Phase 1: Integrate rule engine (2-3 weeks)

The highest-impact change: make rules accessible via `cpm check`.

1. **Static-link RE2 into main binary** — `make build` produces one binary with rules
2. **Add `cpm check --rules`** or integrate into default tier — rules run as part of `cpm check`
3. **Bundle rules in binary or alongside it** — rules/ directory shipped with install
4. **Remove rule-scan as separate binary** — it becomes `cpm rule-scan` subcommand

### Phase 2: Reduce external dependencies (2-3 weeks)

The 14 external tools are the biggest friction. Replace what we can:

| External tool | What it does | Can rules replace it? |
|--------------|-------------|---------------------|
| clang-format | C++ formatting | No (needs AST) |
| shellcheck | Shell linting | Partially (30% of checks) |
| cppcheck | C++ static analysis | Partially (basic patterns) |
| yamllint | YAML syntax | Yes (pattern rules) |
| shfmt | Shell formatting | No (needs parser) |
| semgrep | Multi-lang SAST | Yes (rules replace it fully) |
| vale | Prose linting | Partially (text patterns) |
| gitleaks | Secret scanning | Yes (already have SECRETS-* rules) |
| lychee | Link checking | No (needs HTTP) |
| rumdl | Markdown linting | Partially |
| pmccabe | Complexity | Can build native |
| clang-tidy | C++ quality | No (needs AST) |
| cloc | Line counting | Can build native |
| doxygen | Doc generation | No (different purpose) |

Realistic: rules can replace **semgrep, gitleaks, yamllint** entirely. That removes 3 deps.
Native C++ can replace **pmccabe and cloc**. That removes 2 more.
Result: 14 deps → 9 deps.

### Phase 3: Test quality (2 weeks)

Fix the credibility gap:

1. **Strengthen all checks_test.cpp assertions** — every CHECK(size) gets a CHECK(value)
2. **Add negative tests** — test that clean code produces zero findings
3. **Add edge case tests** — empty files, binary files, huge files, unicode
4. **Validate 875 rules** — run on 10 real repos, measure false positive rate
5. **Remove rules with >50% false positive rate**

### Phase 4: Shell check migration (3-4 weeks)

Migrate shell checks to rules where possible:

- 188 shell checks → estimate ~80 can become rules
- Remaining ~108 need bash (cross-file, aggregation, external tools)
- Goal: `cpm check --fast` runs without bash dependency

### Phase 5: Community readiness (2 weeks)

If the goal is adoption:

1. **Real documentation** — not just ADRs but user-facing guides
2. **cpm.dev website** — or at minimum a good GitHub README (current one is decent)
3. **CI integration examples** — GitHub Actions, GitLab CI, Jenkins
4. **Custom rule authoring guide** — how to write .rule files
5. **Benchmark against semgrep/sonar** — prove the value proposition

## Will C++ Checks Stay?

**Yes, for things regex can't do.** The native checks that should remain:

| Check | Why native | Lines |
|-------|-----------|-------|
| architecture (circular deps) | Needs import graph traversal | 127 |
| dead_code | Needs import graph | 78 |
| framework_misuse | Complex multi-pattern state | 233 |
| regex_quality | Needs regex parsing | 496 |
| doc_* (6 checks) | Complex markdown parsing | ~1400 |
| shadow | Needs scope analysis | 96 |

Total: ~2500 lines of C++ checks that can't be rules. Everything else migrates.

## Timeline (Realistic)

| Phase | Duration | Result |
|-------|----------|--------|
| 0: Clean up | 2 weeks | Credible codebase, no self-findings |
| 1: Integrate rules | 3 weeks | `cpm check` runs all 875 rules |
| 2: Reduce deps | 3 weeks | 9 external tools instead of 14 |
| 3: Test quality | 2 weeks | All tests verify values, not just counts |
| 4: Shell migration | 4 weeks | 80 fewer shell checks |
| 5: Community | 2 weeks | Ready for first external users |
| **Total** | **~16 weeks** | **Production-grade single binary** |

## The Honest Answer

cpm is a **working prototype with good architecture** but **insufficient validation**. The rule engine is solid. The check system works. The design is sound. What's missing is the boring work: fixing shallow tests, validating rules on real projects, integrating the pieces into one coherent tool.

The biggest single change that would make cpm production-grade: **merge rule-scan into the main binary**. Right now the most valuable part of cpm (875 rules) is unreachable to most users.
