# ADR-158: Magic Buffer Size Check (C/C++)

## Status

Accepted (proposed 2026-07-25)

## Context

Raw integer literals in buffer declarations are a recurring source of subtle bugs in C/C++:

1. **Truncation warnings** — `snprintf(dst[128], ...)` with a source that may hold 255 bytes causes
   `-Wformat-truncation` because the compiler knows the sizes don't match.
2. **Copy-paste drift** — a buffer is sized `512` in one place and `256` in another for the same
   logical category (path, command, message), making it unclear which is correct.
3. **Hard to adjust** — changing a path buffer from 512 to 1024 requires a grep across the entire
   codebase instead of a single constant change.

The pattern to enforce:

```c
// bad — magic number, easy to get wrong
char cmd[512];
char path[512];

// good — named constant, category is clear
#define CPM_CMD_MAX  2048
#define CPM_PATH_MAX 1024
char cmd[CPM_CMD_MAX];
char path[CPM_PATH_MAX];
```

cpm itself had 19 such magic-number buffer declarations before introducing `src/common/constants.h`.
That fix is stashed (`stash@{0}`) and will be verified by this check.

## Decision

Add `QUAL-012-magic-buffer-size.rule` to the pluggable rule engine (`rules/quality/`).

Use the existing `pattern` engine — each `char name[NNN]` declaration where `NNN` is a plain integer
≥ 64 is reported as a `warning`. This approach:

- Fits the current rule engine without requiring the not-yet-implemented `metric` engine.
- Each finding is actionable on its own (replace `512` with `CPM_PATH_MAX`).
- Is self-applicable: `cpm rule-scan` on the cpm repo before `stash@{0}` should find all 19
  occurrences; after `git stash apply` it should find zero.

### Rule file

```
id: QUAL-012
title: Magic buffer size literal
category: quality
severity: warning
engine: pattern
target:
  extensions: .c .cpp .h .hpp
  exclude_paths: test/ vendor/ node_modules/ .git/ build/ .tmp/
  content_contains: char
patterns:
  - regex: char\s+[a-zA-Z_][a-zA-Z0-9_]*\s*\[\s*(6[4-9]|[7-9][0-9]|[1-9][0-9]{2,})\s*\]
    message: Magic buffer size — replace with a named constant (e.g. CPM_PATH_MAX, CPM_CMD_MAX)
fix: Introduce a constants.h with named #define or constexpr values grouped by category
```

The regex matches `char identifier[NNN]` where NNN ≥ 64, capturing the most common sources of
`-Wformat-truncation` while ignoring tiny fixed-size fields like `char ext[8]` that are idiomatic.

### What it does NOT flag

- Sizes < 64 (small fixed fields like `char ext[8]` or `char lang[16]` — idiomatic and low-risk).
- Non-char arrays (`int buf[256]` — different concern).
- Already-named constants (`char path[CPM_PATH_MAX]` — the correct pattern).
- Test files (excluded via `exclude_paths`).
- Vendor/generated code.

## Alternatives Considered

- **`metric` engine with threshold:** Cleaner for "N occurrences" semantics but not yet implemented
  in the rule engine. Can migrate when `metric` engine lands (tracked in ADR-145).
- **Shell check in `checks/universal/quality/`:** Legacy path. The rule engine is the right home
  for new checks per ADR-145 migration strategy.
- **`cppcheck` custom rule:** External dependency, slower, requires separate install.

## Consequences

- New warning on any C/C++ project that uses raw integer literals ≥ 64 as buffer sizes.
- Zero findings after applying `stash@{0}` to cpm itself — verified as E2E test.
- Adds one `.rule` file, zero C++ code changes required.
