# ADR-167: AI Slop Detection — Layered Approach

**Status:** Accepted
**Date:** 2026-08-28
**Deciders:** @rkristelijn
**See also:** ADR-166 (rule engine extensions), QUAL-013 (current slop rule)

## Context

cpm is 100% AI-driven. The existing `QUAL-013` rule detects AI filler phrases ("Certainly!", "straightforward") in text. But AI slop has deeper manifestations:

1. **Textual slop** — filler phrases, self-references (current QUAL-013)
2. **Structural slop** — shallow tests, meaningless names, stub functions
3. **Architectural slop** — monolith functions, formula code, no error handling

These are three distinct severity levels. A project might accept level 1 (text) but want to enforce against level 2 (shallow tests) and 3 (architecture).

## Decision

Split AI slop detection into three tiers of rules:

### Tier 1: Textual Slop (`SLOP-0xx`)

AI filler phrases in comments, strings, and documentation. Current QUAL-013 becomes SLOP-001.

| Rule | Detects | Severity |
|------|---------|----------|
| SLOP-001 | AI filler phrases ("Certainly!", "I'd be happy to", "straightforward") | info |
| SLOP-002 | Boilerplate comments that restate the obvious ("This function returns X" on a function named `returnX`) | info |
| SLOP-003 | AI apology/hedge patterns ("Note that", "Keep in mind", "It's worth noting") | info |
| SLOP-004 | Over-commented simple code (comment-to-code ratio >1:1 in a function) | info |

### Tier 2: Structural Slop (`SLOP-1xx`)

Tests and code that exist to satisfy metrics but don't verify behavior.

| Rule | Detects | Severity |
|------|---------|----------|
| SLOP-100 | Size-only test assertions (`CHECK(x.size() == 1)` without verifying content) | warning |
| SLOP-101 | Meaningless test names ("test1", "works", "should work", "it works") | warning |
| SLOP-102 | Empty/trivial catch blocks (`catch(e) {}` or `catch(e) { return; }`) | warning |
| SLOP-103 | Functions that only return a constant (`return true;`, `return "ok";`, `return 0;`) | info |
| SLOP-104 | Commented-out code blocks (>3 consecutive commented lines of code) | info |
| SLOP-105 | Console.log/print as the only "test" (no assertion framework) | warning |
| SLOP-106 | Test without any assertion (test body with no CHECK/REQUIRE/assert/expect) | error |
| SLOP-107 | Weak assertion: `toBeTruthy()`, `toBeDefined()`, `!= null` as sole check | warning |

### Tier 3: Architectural Slop (`SLOP-2xx`)

Patterns that indicate mass-generated code without design thought.

| Rule | Detects | Severity |
|------|---------|----------|
| SLOP-200 | Monolith function (>200 lines in a single function) | warning |
| SLOP-201 | Deep nesting (>4 levels of if/for/while) | warning |
| SLOP-202 | Formula/template code (>5 functions with identical structure) | info |
| SLOP-203 | God file (>1000 lines, single purpose) | warning |
| SLOP-204 | No error handling (function with I/O but no error check) | warning |

## What's Scannable Now

With the current rule engine (pattern + absence + scope):

- **Tier 1:** All rules — pure regex on file content
- **Tier 2:** SLOP-100 through SLOP-107 — regex patterns on test files
- **Tier 3:** SLOP-200 and SLOP-201 only — the rest need aggregation (ADR-166 phase 4)

## Implementation

### Phase 1 (now): Tier 1 + Tier 2 rules as `.rule` files

Tier 1 migrates from QUAL-013. Tier 2 targets test files across languages.

### Phase 2 (future): Tier 3 needs engine extensions

SLOP-200 (function length) and SLOP-202 (formula detection) need counting, which the rule engine can't do yet (ADR-166 phase 4). SLOP-201 (nesting depth) needs stack-based analysis.

## Consequences

**Positive:**
- AI-driven codebases can self-police for generated slop
- Three tiers let teams choose their enforcement level
- Tests that only check `.size()` get flagged, driving deeper assertions
- Complements existing quality rules (QUAL-050 empty catch, STYLE-034 generic names)

**Negative:**
- Some false positives on legitimate size checks (e.g., "collection must have exactly 3 items")
- Tier 3 rules need engine work that doesn't exist yet

**Neutral:**
- QUAL-013 migrates to SLOP-001 (breaking change for existing rule ID references)
- Or keep QUAL-013 as alias and add SLOP-001 as the canonical ID
