# ADR-152: Top 50 Software Engineering Rules of Thumb — Static Checkability Matrix

## Status

Accepted

## Context

We want cpm to enforce as many universally-accepted software engineering principles as possible through static analysis. Not all principles are equally checkable — some require semantic understanding that only humans or AI can provide.

This ADR classifies the top 50 rules of thumb by checkability and documents which cpm checks implement them.

## Decision

We classify each principle into one of four categories:

- ✅ **Fully checkable** — regex/AST/metric based, low false-positive rate
- ⚡ **Partially checkable** — heuristic detection, may need human review
- 🤖 **AI-checkable** — needs context understanding, prompt-fixable
- ❌ **Human only** — requires architectural/domain judgment

## The Matrix

### Structure & Size (8)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 1 | Single Responsibility | ⚡ | `file-too-large`, `too-many-usestate`, `react-prop-drilling` |
| 2 | KISS | ⚡ | `regex-too-complex`, `nested-ternary`, `deep-nesting` |
| 3 | DRY | ✅ | `check-duplication.sh`, `check-dry-patterns.sh` |
| 4 | YAGNI | ⚡ | `you-dont-need`, `barrel-files`, dead code detection |
| 5 | Small functions | ✅ | function-length in `check-file-size.sh` |
| 6 | Small files (<200 lines) | ✅ | `file-too-large` |
| 7 | One abstraction level per function | ❌ | Not checkable without semantic analysis |
| 8 | Flat > nested (max 3 levels) | ✅ | `deep-nesting` in sonar-shift-left |

### Naming (6)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 9 | Descriptive names | ❌ | Not reliably checkable |
| 10 | Consistent casing | ✅ | ESLint naming-convention (delegated) |
| 11 | No abbreviations | ⚡ | `naming-abbreviation` (NEW) |
| 12 | Boolean prefix (is/has/can) | ✅ | `naming-boolean-prefix` (NEW) |
| 13 | Handler naming (handle*/on*) | ✅ | `handler-naming` |
| 14 | File matches export | ⚡ | `naming-file-mismatch` (NEW) |

### Dependencies (5)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 15 | Minimal deps | ✅ | `too-many-deps`, `you-dont-need` |
| 16 | Pin versions | ✅ | `unpinned-deps` |
| 17 | Adapter pattern | ✅ | `check-adapter-pattern.sh` |
| 18 | No deprecated | ✅ | `dead-*`, `you-dont-need` |
| 19 | Correct dep placement | ✅ | `types-in-prod`, `dev-in-prod` |

### Error Handling (4)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 20 | Never swallow errors | ✅ | `owasp-empty-catch`, `async-no-catch` |
| 21 | Fail fast | ⚡ | `api-no-validation` (boundaries) |
| 22 | Loading/error states | ✅ | `no-loading-indicator`, `nextjs-no-error-boundary` |
| 23 | No generic catches | ✅ | `catch-all-cpp`, `a10-catch-all` |

### Security (6)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 24 | Input validation | ✅ | `api-no-validation`, `react19-server-action-no-validation` |
| 25 | No secrets in code | ✅ | `secrets-scan`, `secret-in-public-env` |
| 26 | No eval/innerHTML | ✅ | `eval-usage`, `xss-dangeroushtml` |
| 27 | HTTPS everywhere | ✅ | `insecure-url` |
| 28 | Security headers | ✅ | `nextjs-no-csp`, `nextjs-no-xframe` |
| 29 | Auth defense in depth | ✅ | `nextjs-cve-2025-29927`, `nextjs-middleware-no-guard` |

### Testing (4)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 30 | Tests exist | ✅ | `no-tests`, `low-test-coverage` |
| 31 | Test behavior not impl | ✅ | `test-impl-detail` |
| 32 | No skipped tests | ✅ | `test-skipped` |
| 33 | Error cases tested | ✅ | `test-no-error-cases` |

### Performance (4)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 34 | Lazy load heavy libs | ✅ | `bundle-heavy-static`, `missing-dynamic-import` |
| 35 | Avoid re-renders | ⚡ | `react19-no-compiler`, `react-over-memoization` |
| 36 | Tree-shaking works | ✅ | `barrel-exports`, `lodash-barrel-import` |
| 37 | Optimized images | ✅ | `nextjs-raw-img`, `bundle-no-next-image` |

### API Design (4)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 38 | Correct HTTP verbs | ✅ | `api-get-mutates` |
| 39 | Proper status codes | ✅ | `api-no-error-response` |
| 40 | No stack traces to client | ✅ | `api-leaks-error` |
| 41 | Rate limiting | ✅ | `api-no-rate-limit` |

### Code Style (5)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 42 | Consistent formatting | ✅ | `no-formatter` |
| 43 | No console.log in prod | ✅ | `console-left-in` |
| 44 | No TODO accumulation | ✅ | `excessive-todos` |
| 45 | No commented-out code | ⚡ | `commented-out-code` (NEW) |
| 46 | ESM over CJS | ✅ | `check-module-system.sh` |

### Architecture (4)

| # | Principle | Check | cpm Rule |
|---|-----------|-------|----------|
| 47 | Separation of concerns | ⚡ | `backend-html`, `nextjs-client-layout` |
| 48 | Composition over inheritance | ❌ | Requires OOP semantic analysis |
| 49 | Law of Demeter | ⚡ | Chained property access detectable |
| 50 | Immutability | ✅ | `react-state-mutation` |

## Summary

| Category | Total | ✅ Fully | ⚡ Partial | 🤖 AI | ❌ Human |
|----------|-------|---------|-----------|-------|---------|
| All | 50 | 35 | 12 | - | 3 |

**70% fully checkable, 94% at least partially checkable.**

## New Checks Needed (from this ADR)

1. `naming-abbreviation` — detect `btn`, `mgr`, `impl`, `usr`, `req`, `res`, `ctx`
2. `naming-boolean-prefix` — boolean vars without is/has/can/should prefix
3. `naming-file-mismatch` — filename doesn't match default export
4. `commented-out-code` — blocks of commented code (>3 lines)

## Consequences

- cpm becomes an opinionated code quality framework
- Projects using cpm produce code that adheres to industry principles
- The 3 "human only" principles (descriptive names, abstraction levels, composition) remain the developer's responsibility
