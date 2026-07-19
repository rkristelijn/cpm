# ADR-156: Spaghetti Score — Quantified Code Quality Rating

## Status

Accepted (implemented 2026-07-19)

## Context

We want to give any repository a single numeric score (0-100) that represents "how spaghetti is this code?" — a quick health indicator that answers: "should I trust this codebase?" or "how much tech debt am I inheriting?"

## Decision

Implement `cpm spaghetti [path]` that calculates a score based on the top 20 measurable code smells from Fowler/Martin/SonarQube, weighted by severity.

## Top 20 Code Smells (Measurable)

Based on Martin Fowler's "Refactoring" (2018), Robert C. Martin's "Clean Code", and SonarQube's taxonomy. Only smells that are **statically detectable** are included.

### Bloaters (code that's too big)

| # | Smell | Metric | Weight |
|---|-------|--------|--------|
| 1 | **God File** | File > 300 lines | 5 |
| 2 | **God Function** | Function > 50 lines | 4 |
| 3 | **Too Many Parameters** | Function with > 5 params | 3 |
| 4 | **Deep Nesting** | > 3 levels of if/for/while | 4 |
| 5 | **Primitive Obsession** | > 5 raw string/number params without types | 2 |

### Change Preventers (hard to modify)

| # | Smell | Metric | Weight |
|---|-------|--------|--------|
| 6 | **Shotgun Surgery** | Same pattern in 5+ files (DRY violation) | 4 |
| 7 | **Divergent Change** | File touched in 80%+ of commits (git blame) | 3 |
| 8 | **Tight Coupling** | Import from 10+ different modules | 3 |

### Dispensables (things that shouldn't be there)

| # | Smell | Metric | Weight |
|---|-------|--------|--------|
| 9 | **Dead Code** | Unused exports, unreachable branches | 3 |
| 10 | **Comments Explaining Bad Code** | Inline comment density > 30% | 2 |
| 11 | **Duplicated Code** | > 3% duplication (jscpd/CPD) | 4 |
| 12 | **Speculative Generality** | Unused abstractions, empty interfaces | 2 |

### Couplers (too connected)

| # | Smell | Metric | Weight |
|---|-------|--------|--------|
| 13 | **Feature Envy** | Function using more of another module's data than its own | 3 |
| 14 | **Inappropriate Intimacy** | Circular imports between modules | 4 |
| 15 | **Long Import Chain** | Import depth > 3 levels (../../..) | 2 |

### Complexity Indicators

| # | Smell | Metric | Weight |
|---|-------|--------|--------|
| 16 | **Cyclomatic Complexity** | Function with CC > 10 | 4 |
| 17 | **Inconsistency** | Mixed patterns (require+import, tabs+spaces) | 2 |
| 18 | **Magic Numbers** | Bare numbers in logic without constants | 2 |
| 19 | **No Error Handling** | Async without try/catch, no error boundaries | 3 |
| 20 | **No Tests** | 0% test coverage or no test files | 5 |

## Scoring Formula

```
spaghetti_score = 100 - (total_deductions)

Each smell found:
  deduction = weight × instances × diminishing_factor

  diminishing_factor:
    1st instance: 1.0
    2nd-5th: 0.5
    6th+: 0.2 (capped — one type of smell shouldn't dominate)

Grade:
  90-100: A (clean, professional)
  75-89:  B (good, minor issues)
  50-74:  C (needs attention)
  25-49:  D (significant tech debt)
  0-24:   F (spaghetti — rewrite candidate)
```

## Output

```
$ cpm spaghetti src/

  Spaghetti Score: 72/100 (C)

  Top issues:
    -8  God Files: 3 files > 300 lines
    -6  No Tests: 0 test files found
    -5  Deep Nesting: 4 functions with 4+ levels
    -4  Duplication: 4.2% duplicated code
    -3  Tight Coupling: 2 files import 10+ modules
    -2  Magic Numbers: found in 6 files

  Verdict: Needs attention. Focus on splitting large files and adding tests.
```

## Alternatives Considered

- **SonarQube Maintainability Rating:** Too opaque, can't run offline
- **CodeClimate:** SaaS-only, expensive
- **Custom weighted formula:** What we chose — transparent, adjustable, offline

## Consequences

- Any repo can get a quick health check without configuration
- CI can gate on score (e.g., reject PR if score drops below 60)
- Teams can track improvement over time
- Score is explainable (each deduction is named and weighted)
