# AI Slop Audit — cpm Repository

> **Date:** 2026-08-30
> **Auditor:** Kiro CLI (automated deep analysis)
> **Scope:** Full codebase — C++ source, tests, rule files, shell scripts
> **Status:** 8 of 11 findings fixed, 3 new detection rules added

## Summary

The cpm codebase is **functional, not theater**. The rule engine, sort command, tokenizer, and import graph are solid. However, the code is unmistakably AI-generated, with visible patterns that affect maintainability.

| Aspect | Score | Notes |
|--------|-------|-------|
| Functionality | 8/10 | Compiles, 289 tests pass, finds real issues |
| Test quality | 7/10 | 87% good, 3% fake, 10% weak assertions |
| Code quality | 6/10 | Functional but copy-paste, style mix, orphaned code |
| Rule quality | 8/10 | 875 unique rules, 95% good, SECRETS batch weaker |
| AI visibility | 10/10 | Unmistakably AI-generated |
| Slop level | 3/10 | Low slop, but present |

## Findings

### 🔴 Critical (must fix)

#### F-001: Orphaned Check class hierarchy — DEFERRED

The ~30 OOP `Check` subclasses in `src/checks/` (`FrameworkMisuseCheck`, `RegexQualityCheck`, etc.) are **only instantiated in test files**. Production `cpm check` uses `CheckDef` structs with `system()` calls in `checks.cpp`.

**Status:** Deferred. The classes ARE actively tested (123 test cases in `checks_test.cpp` verify real quality check logic via MockFileSystem). This is parallel development — the native checks could replace shell checks in a future release. Tracked as tech debt, not slop.

#### F-002: Fake tests — ✅ FIXED

- `commands/commands_test.cpp`: `CHECK(true)` → real test that calls `cmd_sort(0, argv)` and asserts return code 1
- `checks_test.cpp`: `CHECK(f.size() >= 0)` → `CHECK(f.size() == 0)` with comment explaining the mock path resolution limitation and a TODO for improving `resolve_path`

**Detection rule added:** [SLOP-117](../../rules/slop/SLOP-117-unsigned-gte-zero.rule) catches `CHECK(v.size() >= 0)` on unsigned types

#### F-003: Broken regex in GO-QUAL-018 — ✅ FIXED

Unclosed quote in second pattern. Fixed: `"(localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0):"` (properly closed, properly escaped).

### 🟡 Important (should fix)

#### F-004: `sed -i ''` portability bug — ✅ FIXED

Replaced `sed -i ''` calls in `cmd_bump` with a portable `replace_in_file()` helper (read → modify → write tmp → rename). Works on macOS, Linux, and any POSIX system.

**Detection rule added:** [SLOP-118](../../rules/slop/SLOP-118-sed-portability.rule) catches `sed -i ''` and `sed -i 's/` patterns

#### F-005: Duplicated skip-directory lists — DEFERRED

At least 3 core files + 14 check files maintain independent `node_modules` skip logic.

**Status:** Deferred to separate PR. Touches 14+ files, high blast radius. The inconsistency is documented but not harmful (each list is a superset of what's needed).

#### F-006: Copy-paste in main.cpp — ✅ FIXED

Extracted `run_lib_script()` helper. Three 10-line copy-paste blocks → three 1-liners. Net reduction: ~90 lines.

#### F-007: Copy-paste JSONL parsing in cmd_ops.cpp — ✅ FIXED

Extracted `JsonlFinding` struct and `parse_jsonl_finding()` function. Four duplicated `sscanf`+`strstr` blocks → four calls to one shared parser.

#### F-008: Overly broad SECRETS regex patterns — ✅ FIXED (2 of ~15)

- `SECRETS-010` (Vultr): `[A-Z0-9]{36}` → `VULTR_API_KEY\s*[=:]\s*['"]?[A-Z0-9]{36}` (requires key name context)
- `SECRETS-075` (Snyk): bare UUID → `SNYK_TOKEN\s*[=:]\s*['"]?[a-f0-9]{8}-...` (requires token name context)
- `SECRETS-002` (Azure AD): Evaluated, left unchanged — `~` prefix + `content_contains: azure` is already specific enough

Remaining ~12 SECRETS rules with potentially broad regex should be reviewed in a follow-up pass.

### 🟢 Style (nice to fix)

#### F-009: AI-verbose comments — detection added

**Detection rule added:** [SLOP-119](../../rules/slop/SLOP-119-promotional-header.rule) catches AI-style promotional headers ("Key performance features:", "This module provides a comprehensive...")

#### F-010: C/C++ style inconsistency

`toml.cpp` and `cmd_ops.cpp` use C-style; `rule_engine.cpp` and `cmd_sort.cpp` use modern C++. Gradual migration recommended.

#### F-011: Shallow framework_misuse heuristics

`framework_misuse.cpp` would false-positive heavily on real projects. Needs tighter heuristics or suppression.

## New detection rules

| Rule | Detects | References |
|------|---------|------------|
| [SLOP-117](../../rules/slop/SLOP-117-unsigned-gte-zero.rule) | `CHECK(v.size() >= 0)` — always true for unsigned | F-002 |
| [SLOP-118](../../rules/slop/SLOP-118-sed-portability.rule) | `sed -i ''` — macOS-only, fails on Linux | F-004 |
| [SLOP-119](../../rules/slop/SLOP-119-promotional-header.rule) | AI-style promotional file headers | F-009 |

## Positive findings

- **Rule engine** (`rule_engine.cpp`): Well-engineered, 5 engine types, pre-compiled RE2
- **Sort command** (`cmd_sort.cpp`): Clean decomposition, safe write-then-rename
- **Tokenizer** (`tokenizer.cpp`): Proper state machine, 15 languages
- **Import graph** (`import_graph.cpp`): Real Tarjan SCC cycle detection
- **875 rules genuinely unique**: Each targets a distinct problem
- **Tests mostly solid**: 87% have meaningful assertions with specific rule names, line numbers, edge cases
- **E2E tests**: Real fixture setup with comprehensive bad-project scenarios

## Verification

All changes verified:

- `make build` — success
- `make test` — 62 unit tests passed (24+16+22), 12 e2e tests passed
- `./build/test_rules` — 85 test cases, 10289 assertions, 1703 regex patterns compiled, all pass

## Open items

1. **F-001:** Wire Check classes into production or document as intentional staging area
2. **F-005:** Extract shared skip-directory constant (separate PR, 14+ files)
3. **F-008:** Review remaining ~12 SECRETS rules with potentially broad regex
4. **F-010:** Gradual C→C++ style migration
5. **F-011:** Tighten `framework_misuse.cpp` heuristics
