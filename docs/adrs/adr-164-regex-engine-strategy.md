# ADR-164: Regex Engine Strategy for Rule Engine

**Status:** Proposed  
**Date:** 2026-08-17  
**Author:** Remi Kristelijn

## Context

The cpm rule engine (`src/rules/rule_engine.cpp`) currently depends on Google's `re2` library for regex matching. This creates a compile-time dependency that blocks zero-dependency builds and complicates CI integration (e.g. running cpm in Standard Components pipelines).

Our actual regex needs are minimal — 35 Go rules with simple patterns like `time\.Sleep\(`, `os\.Exit\(`, `"crypto/md5"`. No captures, no lookahead, no Unicode classes.

## Current Problem

- `re2` requires `brew install re2` or `apk add re2-dev` before building
- This blocks CI integration where the build environment is controlled
- The existing C++ checks (crypto.cpp, owasp.cpp) already work fine with `std::string::find()` — no regex at all
- re2 is ~20k LOC solving problems we don't have (DFA caching, thread safety, Unicode, bounded memory)

## Decision

Phase approach — simplest first, optimize only if measured:

### Phase 1: Replace re2 with std::regex (immediate)

- Zero dependencies, built into C++11
- Sufficient for our patterns (no catastrophic backtracking risk with simple patterns)
- ~3 lines of code change in rule_engine.cpp
- Build becomes: `g++ -std=c++17 -O2 -o cpm ...` — nothing else needed

### Phase 2: Hybrid string-match + regex (optimization)

Most of our patterns are effectively literal string searches with optional anchoring:
- `os\.Exit\(` → `find("os.Exit(")`
- `"crypto/md5"` → `find("\"crypto/md5\"")`

Strategy:
- Pre-analyze each rule pattern at load time
- If pattern is a literal (no metacharacters): use `std::string::find()` (fastest)
- If pattern needs regex: use `std::regex` (fallback)
- Expected result: 80% of patterns use find(), 20% use regex

### Phase 3: Minimal custom engine (optional, side project)

If std::regex ever becomes a bottleneck (~impossible at our scale), write or vendor a minimal NFA engine:

**Requirements (subset of regex):**
- Literal matching
- Character classes: `[A-Z0-9]`, `[^"]`, `\s`, `\w`, `\b`
- Quantifiers: `+`, `*`, `?`
- Alternation: `|`
- Anchors: `^`, `$`
- Escapes: `\.`, `\(`, `\\`

**NOT needed:**
- Captures/groups (we don't extract, only detect)
- Lookahead/lookbehind
- Backreferences
- Unicode character class tables
- Thread-safe DFA caching
- Bounded memory guarantees

**Estimated size:** 200-500 LOC  
**Existing options:** tiny-regex-c (500 LOC, public domain), Rob Pike-style NFA (~200 LOC)

## Comparison

| Approach | LOC | Dependencies | Build time | Performance | Complexity |
|----------|-----|-------------|-----------|-------------|:----------:|
| re2 (current) | 0 (external) | brew/apk install | +0s (pre-installed) | O(n) guaranteed | Low (for us) |
| re2 submodule | +20k | None (vendored) | +10-15s | O(n) guaranteed | Medium |
| std::regex | 0 | None (C++11) | +0s | O(n) for simple patterns | Low |
| Hybrid find+regex | ~50 | None | +0s | Fastest for literals | Low |
| Custom mini engine | 200-500 | None | +0.5s | O(n) (NFA) | Medium |
| CTRE header-only | ~3k (1 file) | None | +1-2s | Compile-time optimized | Low |

## Recommendation

**Do Phase 1 now** (std::regex) — removes the blocker, zero effort.  
**Do Phase 2 later** (hybrid) — only if profiling shows regex is hot path (unlikely at 15ms total scan).  
**Phase 3 is a fun side project** — not a priority, but educational.

## Context: Why re2 exists

re2 solves a real problem — but not ours:
- **Google:** untrusted user-supplied regex on massive datasets → needs guaranteed O(n), bounded memory
- **Cloudflare WAF:** millions of requests/sec against complex rule patterns → needs DFA speed
- **cpm:** 35 fixed patterns on <10 files totaling <50KB → `find()` is literally fast enough

## Consequences

- Zero-dependency build enables CI integration (Standard Components, GitHub Actions)
- No functional change — same rules, same output
- Slightly slower regex matching (irrelevant at our scale)
- Opens path for `cpm` as a Standard Component in GitLab pipelines

## References

- [re2 source](https://github.com/google/re2) — BSD-3, ~20k LOC
- [tiny-regex-c](https://github.com/kokke/tiny-regex-c) — public domain, ~500 LOC
- [CTRE](https://github.com/hanickadot/compile-time-regular-expressions) — MIT, header-only
- Rob Pike, "Regular Expression Matching Can Be Simple And Fast" (2007)
- ADR-145: Pluggable Rule Engine
- ADR-163: Go Language Support
