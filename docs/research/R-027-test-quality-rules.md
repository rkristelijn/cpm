# Research: Test Quality Rules — Academic Foundation & Multi-Framework Coverage

**Date:** 2026-08-28
**Status:** Research + Implementation
**See also:** ADR-167 (AI slop detection), testsmells.org, xUnit Test Patterns (Meszaros 2007)

## Objective

Define test quality rules for cpm that are:
- **Evidence-based** — grounded in academic test smell research, not opinion
- **Non-opinionated about methodology** — don't force AAA, Gherkin, or any pattern; detect inconsistency within chosen patterns
- **Multi-framework** — cover the test frameworks used across cpm's 14 supported languages
- **Actionable** — every finding explains what's wrong and how to fix it

## Academic Foundation

### Canonical Test Smell Catalogs

Three authoritative sources define the test smell taxonomy:

1. **Van Deursen et al. (2001)** — "Refactoring Test Code" (XP2001). Defined 11 original smells including Assertion Roulette, Mystery Guest, Eager Test.
2. **Meszaros (2007)** — "xUnit Test Patterns" (Addison-Wesley). 18 smells + refactoring patterns. Industry standard reference.
3. **testsmells.org (RIT Rochester)** — 19 smells with open-source detection tool. Academically validated on Java/Android.

### Key Research Findings

- **Assertion Roulette is the most pervasive smell** in both industrial and open-source systems (ResearchGate 2022).
- **Students take significantly longer to debug** when test smells are present, especially Assertion Roulette and Eager Test (Arxiv 2024, DOI: 2303.04234).
- **Google's 70/20/10 split** (unit/integration/e2e) is the most widely cited numeric guidance for test distribution.
- **Meta's predictive test selection** catches >99.9% of issues running only ~33% of tests — proving that test quality matters more than quantity.

### The Weak Assertion Problem

Academic evidence is clear: **weak assertions reduce defect detection probability to near zero while inflating coverage metrics.**

| Assertion type | What it actually tests | Defect detection |
|---|---|---|
| `expect(x).toBeDefined()` | x !== undefined | Near zero — any value passes |
| `expect(x).toBeTruthy()` | x is not falsy | Near zero — wrong values pass |
| `assert result` (Python) | result is truthy | Near zero |
| `assertNotNull(x)` (Java) | x != null | Near zero — wrong object passes |
| `if err != nil { t.Fatal }` (Go) | No error occurred | Partial — doesn't verify the result |
| `CHECK(f.size() == 1)` (C++) | One finding exists | Partial — doesn't verify which finding |

These are worse than no test: they create a false sense of security. Coverage tools report the code as tested, but the test would pass even if the production code returned completely wrong values.

## Design Principles for Test Rules

### 1. Detect problems, don't prescribe methodology

**Wrong:** "Tests must use AAA pattern" (opinionated)
**Right:** "If a file uses AAA pattern for some tests and non-AAA for others, flag inconsistency" (evidence-based)

### 2. Promote consistency, not conformity

**Wrong:** "Use Gherkin for all tests" (prescriptive)
**Right:** "If a file uses Given/When/Then structure, all steps should have implementations" (consistency)

### 3. Severity reflects impact

| Severity | Meaning | Example |
|----------|---------|---------|
| error | Test provides false confidence | Empty test body, redundant assertion (always passes) |
| warning | Test is weak but provides some value | Weak assertion, sleep in test, shared mutable state |
| info | Style issue, low defect risk | Magic number in assertion, inconsistent structure |

## Complete Test Smell Coverage Map

### 19 Academic Smells (testsmells.org) → cpm Rules

| # | Smell | Academic source | cpm rule(s) | Status |
|---|-------|----------------|-------------|--------|
| 1 | Assertion Roulette | Van Deursen | TEST-037 (assertion in loop) | ✅ Partial |
| 2 | Conditional Test Logic | Meszaros | TEST-030 | ✅ |
| 3 | Constructor Initialization | testsmells.org | — | ⬜ Java-specific, low priority |
| 4 | Default Test | testsmells.org | — | ⬜ Android-specific |
| 5 | Duplicate Assert | testsmells.org | TEST-032 (redundant) | ✅ |
| 6 | Eager Test | Van Deursen | — | ⬜ Needs cross-function analysis |
| 7 | Empty Test | testsmells.org | TEST-031 | ✅ |
| 8 | Exception Handling | testsmells.org | — | ⬜ Needs structural analysis |
| 9 | General Fixture | testsmells.org | — | ⬜ Needs cross-method analysis |
| 10 | Ignored/Skipped Test | testsmells.org | TEST-015, TEST-025 | ✅ |
| 11 | Lazy Test | Van Deursen | — | ⬜ Needs cross-method analysis |
| 12 | Magic Number Test | testsmells.org | TEST-033 | ✅ |
| 13 | Mystery Guest | Van Deursen | TEST-021, TEST-027, TEST-036 | ✅ |
| 14 | Redundant Print | testsmells.org | TEST-017, SLOP-105 | ✅ |
| 15 | Redundant Assertion | testsmells.org | TEST-032 | ✅ |
| 16 | Resource Optimism | testsmells.org | TEST-036 | ✅ |
| 17 | Sensitive Equality | testsmells.org | — | ⬜ Low priority |
| 18 | Sleepy Test | testsmells.org | TEST-014, TEST-035 | ✅ |
| 19 | Unknown Test | testsmells.org | TEST-031 | ✅ |

**Coverage: 13/19 smells (68%)** — remaining 6 need structural or cross-function analysis beyond regex.

### Framework-Specific Coverage

| Framework | Language | Rules | Weak assertion | Sleep | Empty test | Filesystem | Structure |
|-----------|---------|-------|---------------|-------|-----------|------------|-----------|
| **Jest/Vitest** | JS/TS | 14 | SLOP-107 | TEST-035 | TEST-031 | TEST-036 | TEST-034 |
| **Mocha** | JS | 4 | SLOP-107 | TEST-035 | TEST-031 | TEST-036 | — |
| **Cypress** | JS/TS | 2 | — | TEST-024 | — | — | — |
| **Angular TestBed** | TS | 2 | SLOP-107 | — | — | — | TEST-044 |
| **Pytest** | Python | 5 | TEST-040 | TEST-035 | TEST-031 | TEST-036 | — |
| **JUnit 5** | Java | 4 | TEST-039 | TEST-035 | TEST-031 | TEST-036 | — |
| **Go testing** | Go | 4 | TEST-041 | TEST-035 | TEST-031 | TEST-036 | — |
| **doctest** | C++ | 3 | SLOP-100 | — | — | — | — |
| **RSpec** | Ruby | 2 | — | TEST-035 | TEST-031 | — | — |
| **Cucumber/Gherkin** | Multi | 1 | — | — | TEST-043 | — | — |
| **Rust #[test]** | Rust | 1 | — | TEST-035 | — | — | — |
| **PHPUnit** | PHP | 0 | — | — | — | — | — |
| **Swift XCTest** | Swift | 0 | — | — | — | — | — |
| **xUnit/NUnit** | C# | 0 | — | — | — | — | — |

### Cross-Cutting Rules (all languages)

| Rule | What | Severity | Frameworks |
|------|------|----------|------------|
| TEST-031 | Empty test body (Unknown Test) | error | All |
| TEST-032 | Redundant assertion (always passes) | error | All |
| TEST-033 | Magic number in assertion | info | All |
| TEST-035 | Sleep/wait in test (Sleepy Test) | warning | All |
| TEST-036 | Real filesystem access (Mystery Guest) | warning | All |
| TEST-037 | Assertion in loop (Assertion Roulette) | warning | All |
| TEST-038 | Duplicate test name | warning | All |
| TEST-042 | Shared mutable state (test order dependency) | warning | All |
| SLOP-100/101/102 | Size-only assertion | warning | C++, JS, Python |

## On Methodology: AAA, Gherkin, and Consistency

cpm does **not** enforce AAA, Gherkin, BDD, or any specific test methodology. The philosophy:

### AAA (Arrange-Act-Assert)
If you use it, use it consistently. TEST-034 detects mixed patterns in the same file. cpm does not flag non-AAA tests — it flags files where *some* tests follow AAA and others don't.

### Gherkin / Cucumber / BDD
If you write Given/When/Then steps, they must have implementations. TEST-043 detects empty step definitions. cpm does not require Gherkin — it ensures that if you chose it, you followed through.

### One assertion per test
Academically recommended (Van Deursen) but controversial in practice. cpm does not enforce this. Instead, TEST-037 flags assertions *inside loops* (the Assertion Roulette anti-pattern) where failure location is lost.

## Confluence Reference

APS Group's Confluence documents testing practices in:
- **"How to: Test a frontend"** — scope definitions (unit/integration/e2e), Google 70/20/10 split, anti-flake practices, tooling (Jest, Vitest, React Testing Library, Angular TestBed, Cypress, Playwright)
- **"Test Driven Development using Cypress and Jest"** — Jest vs Cypress comparison, when to use shallow vs deep rendering, mocking strategies

Key alignment: cpm's test rules reinforce the practices documented on Confluence without mandating a specific approach. If a team uses Jest with AAA — cpm validates consistency. If a team uses Cypress with page objects — cpm validates that step definitions are complete.

## Implementation

35 test rules in `rules/test/` (up from 21), plus 8 SLOP rules = **43 total test quality rules**.

### New rules created (this session)

| Rule | Smell | Languages |
|------|-------|-----------|
| TEST-031 | Empty Test / Unknown Test | JS/TS/Java/Go/Python/Ruby |
| TEST-032 | Redundant Assertion | JS/TS/Java/Go/Python/C++ |
| TEST-033 | Magic Number Test | JS/TS/Java/Go/Python/C++ |
| TEST-034 | Inconsistent Structure | JS/TS |
| TEST-035 | Sleepy Test (broad) | JS/TS/Java/Go/Python/Ruby/Rust/C++ |
| TEST-036 | Mystery Guest (filesystem) | JS/TS/Java/Go/Python |
| TEST-037 | Assertion Roulette (loop) | JS/TS/Java/Go/Python/C++ |
| TEST-038 | Duplicate Test Name | JS/TS/Java/Go/Python |
| TEST-039 | Weak Assertion (Java) | Java |
| TEST-040 | Weak Assertion (Python) | Python |
| TEST-041 | Weak Assertion (Go) | Go |
| TEST-042 | Test Order Dependency | JS/TS/Java/Python |
| TEST-043 | Empty Gherkin Step | JS/Java/Ruby/Python |
| TEST-044 | Angular TestBed Leak | Angular/TS |

## Gaps (Future Work)

| Smell | Why not now | Needed engine feature |
|-------|-----------|---------------------|
| Eager Test | Need to count distinct production method calls per test | Aggregation (ADR-166 phase 4) |
| General Fixture | Need to compare setUp fields vs test usage | Cross-method analysis |
| Lazy Test | Need to detect multiple tests calling same method | Cross-method analysis |
| Exception Handling | Need to detect try/catch wrapping assertions | Structural (nesting analysis) |
| PHPUnit / xUnit / Swift | Low usage in current user base | Add when demand exists |
