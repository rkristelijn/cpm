# ADR-153: Native Regex Quality Check (C++)

## Status

Accepted (implemented 2026-07-19)

## Context

A broken shell quoting bug in `owasp-cors-wildcard` caused false positives on every project. The root cause: a single quote inside a single-quoted grep regex in a C string. No existing tool validates regex correctness in the context of shell quoting, BRE/ERE/PCRE dialect differences, and ReDoS patterns simultaneously.

## Decision

Implement `regex-quality` as a **native C++ check** (not a shell script) because:

- It needs to parse C string escape sequences to validate shell commands
- It needs to understand BRE vs ERE vs PCRE context per tool
- Performance: scans all .sh + source files in one pass
- Self-validation: can check cpm's own CHECK_DEFS[] at compile time via unit tests

## Rules Implemented (12)

**Security (error):**
- `redos-nested-quantifiers` — (a+)+ catastrophic backtracking
- `redos-overlapping-alternation` — (a|a)+ exponential paths

**Correctness (error/warning):**
- `shell-quoting-mismatch` — broken quotes in grep/sed
- `missing-anchor-validation` — /pattern/.test() without ^/$
- `empty-alternative` — leading/trailing | or ||
- `unescaped-dot` — 1.2.3 matching 1X2X3

**Portability (warning):**
- `pcre-in-ere-context` — \d in grep -E
- `grep-p-not-portable` — macOS/BSD incompatible
- `sed-r-not-portable` — GNU-only
- `bre-ere-mismatch` — bare + in BRE

**Style (info):**
- `single-char-alternation` — a|b|c → [abc]
- `regex-too-complex` — score > 20

## Alternatives Considered

- **Shell-only check:** Can't parse C string escaping reliably
- **eslint-plugin-regexp:** JS only, no shell/grep awareness
- **SonarQube regex rules:** No shell quoting context, can't self-validate

## Consequences

- 28 unit tests with 96.4% coverage
- Prevents the entire class of "check fails because regex is broken" bugs
- Design doc at `docs/designs/regex-quality-check.md` for Phase 2-4 roadmap
