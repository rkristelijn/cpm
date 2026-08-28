# Research: AI-Assisted Development Quality — What Goes Wrong and How to Catch It

**Date:** 2026-08-28
**Status:** Research
**See also:** ADR-167 (AI slop detection), R-027 (test quality rules)

## The Evidence

### CodeRabbit "State of AI vs Human Code" (Dec 2025)
Analysis of 470 real-world open-source PRs. AI-generated code has **1.7× more issues** than human code:
- Logic & correctness: **1.75×** more errors
- Code quality & maintainability: **1.64×** more issues
- Security: **1.57×** more findings
- Performance: **1.42×** more issues

### Ox Security "Army of Juniors" (Oct 2025)
Analysis of 300+ repositories. Key insight: **AI is not more buggy per line — it repeats the same structural shortcuts at scale.** AI behaves like "an army of talented junior developers: fast, eager, confident, but missing architectural judgment."

### Arxiv: Human vs AI Code (2025)
"AI-generated code is generally simpler and more repetitive, yet more prone to **unused constructs** and **hardcoded debugging**, while human-written code exhibits greater structural complexity."

### METR Randomized Trial (2025)
Experienced developers were **19% slower** with AI tools on real-world complex codebases, despite **feeling 20% faster**. The perception gap is one of the biggest risks.

## The 10 AI Code Anti-Patterns (Ox Security)

| # | Pattern | Prevalence | Detectable by cpm? | How |
|---|---------|-----------|--------------------|----|
| 1 | **Comment Overload** | 90-100% | 🟡 Partial | SLOP-002 catches obvious comments, but comment density ratio is SLOP-204 (future) |
| 2 | **By-the-Book Fixation** | 80-90% | ❌ No | Requires understanding design context vs textbook pattern |
| 3 | **Over-Specification** | 80-90% | ❌ No | Requires understanding code reuse opportunities |
| 4 | **Avoidance of Refactors** | 80-90% | 🟡 Partial | Detectable via churn analysis (new code never modifies existing) |
| 5 | **Bugs Déjà-Vu** (repeated patterns) | 70-80% | 🟢 Yes | extract-duplicates engine can find repeated code blocks |
| 6 | **"Worked on My Machine"** | 60-70% | 🟡 Partial | TEST-036 (filesystem access), env-config checks |
| 7 | **Return of Monoliths** | 40-50% | 🟡 Partial | SLOP-200 (monolith function, future), architecture checks |
| 8 | **Fake Test Coverage** | 40-50% | 🟢 Yes | SLOP-100/101/102/107, TEST-031/032 |
| 9 | **Vanilla Style** (NIH/reinventing) | 40-50% | 🟡 Partial | Can detect common reimplementations |
| 10 | **Phantom Bugs** (over-engineering) | 20-30% | ❌ No | Requires understanding actual requirements |

## cpm Gap Analysis: What We Miss

### Currently detectable (already have rules)

| AI Problem | cpm Rules | Coverage |
|-----------|----------|----------|
| AI filler text | SLOP-001/002/003 | ✅ Good |
| Shallow/fake tests | SLOP-100-107, TEST-031/032 | ✅ Good |
| Weak assertions | TEST-022, TEST-039-041, SLOP-107 | ✅ Good |
| Hardcoded secrets | SECRETS-* (80 rules) | ✅ Good |
| Missing error handling (partial) | Various OWASP rules | 🟡 Partial |
| Unused imports | — | ❌ Missing |

### New checks needed for AI-driven development

#### High priority — directly scannable

| Check | AI Problem | Detection | Difficulty |
|-------|-----------|-----------|------------|
| **SLOP-110: Unused imports/requires** | AI adds imports it doesn't use | `import X from Y` where X never appears in file body | Medium (cross-line) |
| **SLOP-111: Unused variables** | AI declares vars it never uses | `const x = ...` where x never appears after declaration | Medium (cross-line) |
| **SLOP-112: Hardcoded debug artifacts** | AI leaves console.log, debugger, TODO | `console.log`, `debugger;`, `print(f"DEBUG` in non-test code | Easy (pattern) |
| **SLOP-113: Inconsistent error handling** | Some funcs use try/catch, others don't | Mix of error strategies in same file | Medium (cross-function) |
| **SLOP-114: NIH reimplementation** | AI rewrites lodash.debounce, Array.flat, etc. | Known patterns for standard library functions | Easy (pattern) |
| **SLOP-115: Stale/orphaned functions** | AI generates functions never called | Function defined but never referenced (cross-file) | Hard (phase 2 engine) |
| **SLOP-116: Inconsistent naming convention** | Mix of camelCase/snake_case in same file | `const myFunc` + `const my_func` in same scope | Easy (pattern) |
| **SLOP-117: Copy-paste code across files** | Same 5+ lines repeated in multiple files | Identical function bodies | Hard (phase 4 engine) |
| **SLOP-118: Hallucinated API** | AI calls methods that don't exist on the object | `array.flatMap` in environments that don't support it | Hard (needs type info) |
| **SLOP-119: Over-commented simple code** | Comment ratio >1:1 in a function | More comment lines than code lines | Medium (counting) |

#### Medium priority — detectable with engine extensions

| Check | AI Problem | Needed engine |
|-------|-----------|--------------|
| **SLOP-120: Context drift** | Variable used differently from declaration | Needs data flow analysis |
| **SLOP-121: Dead branches** | if/else where one branch is unreachable | Needs constant analysis |
| **SLOP-122: Monolith function** | Function >200 lines | Needs counting (ADR-166 phase 4) |
| **SLOP-123: Deep nesting** | >4 levels of if/for/while | Needs nesting tracking |

#### Low priority — need external tools or runtime

| Check | Why not scannable |
|-------|------------------|
| Architectural drift | Needs system-level understanding |
| Performance regression | Needs runtime profiling |
| API hallucination (full) | Needs type system / LSP |
| Semantic correctness | Needs specification to verify against |

## What Other Tools Do

| Tool | AI-specific detection | Approach |
|------|---------------------|----------|
| **CodeRabbit** | Flags AI-pattern code in PR review | LLM-powered semantic analysis |
| **Sourcery** | Detects code duplication, unused code | AST-based Python analysis |
| **DeepSource** | Dead code, anti-patterns, security | Multi-lang static analysis |
| **SonarQube** | Code smells, cognitive complexity | Rule-based (3000+ rules) |
| **Semgrep** | Pattern matching with AST awareness | Custom rules, AST-based |
| **Fallow** | AI slop cleanup for TypeScript | Specialized: dead code, tangled deps |

cpm's unique position: **zero-dependency, declarative rules, single-pass regex scanning**. We can't match AST tools for precision, but we can catch 80% of AI anti-patterns with regex at 10× the speed.

## Recommendations for cpm

### Phase 1: Easy wins (pattern rules, implementable now)

1. **SLOP-112: Debug artifacts in production code** — `console.log`, `debugger`, `print("DEBUG` outside test files
2. **SLOP-114: NIH reimplementations** — detect hand-rolled debounce, throttle, deepClone, flatMap, etc.
3. **SLOP-116: Mixed naming conventions** — camelCase + snake_case in same file

### Phase 2: Cross-line analysis (needs extract engine)

4. **SLOP-110: Unused imports** — extract all imports, check if identifiers appear in file body
5. **SLOP-111: Unused variables** — extract declarations, check usage
6. **SLOP-119: Over-commented code** — count comment lines vs code lines per function

### Phase 3: Cross-file (needs ADR-166 phase 2)

7. **SLOP-115: Orphaned functions** — function never called from any file
8. **SLOP-117: Cross-file duplication** — identical blocks across files

### What to tell AI users

The research is clear: **AI makes you faster at writing code and slower at finding bugs in it.** The METR trial shows developers *feel* 20% faster but *are* 19% slower on complex tasks. The mitigation isn't "don't use AI" — it's "use AI with automated quality checks that catch what you won't."

cpm's value proposition for AI-driven development:
1. Every finding explains WHY and HOW to fix (learn don't police)
2. Checks run pre-commit/pre-push (catch before merge, not after)
3. Organic growth: start with `learn` level, grow to `enforce` when ready
4. AI-specific rules (SLOP-*) that catch patterns unique to AI generation
5. Compliance mapping so AI-generated code still meets regulatory standards
