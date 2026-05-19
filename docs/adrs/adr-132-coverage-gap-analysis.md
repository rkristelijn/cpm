---
summary: Coverage gap analysis — what cpm detects vs. SonarQube, and where to invest next.
status: accepted
---

# ADR-132: Coverage Gap Analysis & SonarQube Comparison

*Date*: 2026-05-19
*Related*: [ADR-020](adr-020-product-vision.md), [ADR-131](adr-131-sql-antipattern-detection.md)

## Context

cpm has grown to 125 checks (92 shell + 33 C++). But how does this compare to industry-standard tools like SonarQube? And where are our blind spots?

## cpm vs. SonarQube — Honest Comparison

### By the numbers

| Metric | SonarQube | cpm | cpm % |
|--------|-----------|-----|-------|
| Total rules | ~5,000+ | ~125 | **2.5%** |
| Languages supported | 30+ | 7 (specific) + universal | **23%** |
| Framework-specific rules | ~500 | ~40 | **8%** |
| Security rules (OWASP) | ~400 | ~50 | **12%** |
| Code smell rules | ~2,000 | ~30 | **1.5%** |
| Bug detection rules | ~1,500 | ~20 | **1.3%** |
| SQL-specific rules | ~50 | ~50 | **100%** ✓ |
| Shell/Bash rules | ~20 | ~30 | **150%** ✓ |
| Maturity/process rules | 0 | ~25 | **∞** ✓ |
| Architecture rules | ~10 | ~15 | **150%** ✓ |

### Where cpm wins

| Area | Why cpm is better |
|------|-------------------|
| **Zero friction** | No server, no config, instant results |
| **Maturity model** | SonarQube has quality gates, cpm has progressive maturity levels |
| **Process enforcement** | Conventional commits, issue tracking, V-model — Sonar doesn't do this |
| **Shell/Bash** | More patterns than Sonar (dangerous commands, evil patterns) |
| **SQL anti-patterns** | Full Bill Karwin coverage + DB-specific, Sonar only does basic SQL |
| **Architecture** | Circular deps, fan-out, coupling — Sonar needs plugins |
| **Local-first** | Works offline, no server, no license |
| **Polyrepo scan** | Scan 100+ repos in <1s — Sonar can't |
| **Learning** | Every finding teaches (what, why, fix, docs) |

### Where SonarQube wins (our gaps)

| Area | Sonar rules | cpm rules | Gap |
|------|-------------|-----------|-----|
| **Python** | 400+ | 5 (universal only) | Critical |
| **Java** | 600+ | 1 | Critical |
| **C#/.NET** | 400+ | 0 | Critical |
| **Go** | 150+ | 0 | High |
| **Kotlin** | 200+ | 0 | High |
| **Ruby** | 100+ | 0 | Medium |
| **Vue.js** | 50+ | 0 | Medium |
| **Type system** | Deep flow analysis | Regex only | Fundamental |
| **Data flow** | Taint analysis | None | Fundamental |
| **Duplication** | AST-based | Line-based | Medium |
| **Complexity** | Cognitive complexity | Cyclomatic only | Low |
| **Test coverage** | Integration | External tool | Low |

### Fundamental architectural difference

```text
SonarQube:
  Source → AST Parser → Semantic Model → Rule Engine → Findings
  (deep understanding of code, cross-file analysis, type resolution)

cpm:
  Source → grep/regex → Pattern Match → Findings
  (fast, zero-dep, but no semantic understanding)
```

**What this means:**
- Sonar can detect "this variable might be null at line 42" — cpm cannot
- Sonar can trace data flow from user input to SQL query — cpm cannot
- cpm can detect "this file has no @see reference" — Sonar cannot
- cpm can detect "this repo has no CONTRIBUTING.md" — Sonar cannot

### Realistic positioning

```text
SonarQube = Deep code analysis (per-language, per-file, semantic)
cpm       = Broad quality orchestration (any repo, process + code + docs)
```

They're complementary, not competing. cpm is the **orchestration layer** that:
1. Runs before Sonar (shift-left, pre-commit)
2. Catches what Sonar misses (process, architecture, docs, maturity)
3. Orchestrates Sonar (can invoke it as a tool in `cpm check --full`)

## Gap Prioritization

### Tier 1: High impact, low effort (add next)

| Gap | Impact | Effort | How |
|-----|--------|--------|-----|
| Python basics | High (huge market) | Low | 15 regex patterns for common anti-patterns |
| Vue.js/Nuxt | Medium | Low | Similar to React check |
| Kubernetes/Helm | Medium | Low | YAML pattern checks |
| Performance: batch findings_add | High (blocking) | Medium | Buffer + single write |

### Tier 2: High impact, medium effort

| Gap | Impact | Effort | How |
|-----|--------|--------|-----|
| Java/Spring | High (enterprise) | Medium | 25 patterns |
| C#/.NET | High (enterprise) | Medium | 25 patterns |
| Go | Medium | Medium | 15 patterns |
| GitLab CI | Medium | Low | YAML checks |

### Tier 3: Medium impact, high effort (future)

| Gap | Impact | Effort | How |
|-----|--------|--------|-----|
| Data flow / taint analysis | Very high | Very high | Requires AST, out of scope for grep |
| Type-aware analysis | Very high | Very high | Requires language server |
| Duplication (AST-based) | Medium | High | Requires parser per language |
| Cognitive complexity | Low | Medium | Requires AST |

### Tier 4: Delegate to tools (don't build)

| Gap | Tool to orchestrate |
|-----|-------------------|
| Deep Python analysis | Ruff, Pylint, Bandit |
| Deep Java analysis | SpotBugs, PMD, ErrorProne |
| Deep C# analysis | Roslyn analyzers |
| Deep Go analysis | golangci-lint |
| Deep Rust analysis | clippy |
| Taint analysis | Semgrep, CodeQL |

**cpm's role:** orchestrate these tools, normalize their output to JSONL findings, and add what they miss (process, docs, architecture).

## Decision

1. **Don't compete with Sonar on deep per-language analysis** — that's a losing battle
2. **Win on breadth:** process, architecture, docs, maturity, multi-repo
3. **Win on speed:** pre-commit in <5s, no server needed
4. **Win on learning:** every finding teaches
5. **Orchestrate deep tools** when available (semgrep, eslint, ruff, etc.)
6. **Add language checks** only for patterns that grep can reliably detect (top 15-25 per language)

## Enforcement

| What | How | Automation |
|------|-----|-----------|
| Coverage gaps tracked | This ADR + issues | `cpm issue` per gap |
| New language checks follow template | `lib/shell/check.sh` pattern | `check-test-architecture.sh` |
| Performance monitored | `TEST_WARN_MS` / timing | E2E profiling |

## References

- @see ADR-131 (SQL anti-pattern detection)
- @see ADR-129 (unified findings contract)
- @see ADR-013 (product positioning — "not a linter, orchestrates linters")
- [SonarQube rules](https://rules.sonarsource.com/)
- [Semgrep registry](https://semgrep.dev/r)
