# ADR-160: Zero Warnings Policy (C++)

## Status

Accepted (2026-07-26)

## Context

cpm compiles with `-Wall -Wextra` but currently produces ~28 warnings across two categories:

1. **`-Wformat-truncation`** (8 warnings) — `snprintf` destination smaller than source buffer.
   The compiler sees `char line[2048]` flowing into `char key[128]` and warns, even though
   truncation is intentional and safe (snprintf null-terminates).

2. **`-Wunused-result`** (20 warnings) — return values of `system()`, `readlink()`, `pipe()`
   ignored. These are fire-and-forget calls where the return value is not actionable.

A quality tool that doesn't compile clean is a bad look. We need zero warnings on all platforms.

## Decision

Fix warnings properly in code rather than suppressing with `-Wno-` flags.

### Category 1: Buffer sizes (format-truncation)

Use the buffer size hierarchy from `src/common/constants.h` (ADR-158):

```
CPM_PATH_MAX (1024) — filesystem paths
CPM_CMD_MAX  (2048) — shell commands (contains paths + formatting)
CPM_LINE_MAX (2048) — input lines (file read, popen output)
CPM_MSG_MAX  (2048) — human-readable messages
CPM_NAME_MAX (256)  — short identifiers (repo name, check name)
```

**Rule:** A destination buffer must be ≥ the source buffer, OR the function must clearly operate
on a shorter substring (e.g. basename after strrchr). When the destination is intentionally smaller
(TOML parser clipping keys to struct fields), use a pragma block with a comment explaining why.

### Category 2: Unused results (warn_unused_result)

Use a cross-platform macro in `src/common/compat.h`:

```cpp
#ifdef _MSC_VER
#define CPM_DISCARD(expr) (void)(expr)
#elif defined(__GNUC__)
#define CPM_DISCARD(expr) do { __typeof__(expr) _r __attribute__((unused)) = (expr); (void)_r; } while(0)
#else
#define CPM_DISCARD(expr) (void)(expr)
#endif
```

- Uses `__typeof__` (GCC extension, available since GCC 3) instead of C++17 `auto` for C compat.
- MSVC respects `(void)` cast so the simple form works there.
- Clang respects `(void)` cast but also supports the GCC path.

**Rule:** Every `system()`, `readlink()`, `pipe()` call that intentionally ignores the result
must use `CPM_DISCARD(...)`. Calls where the result matters (e.g. `system()` return fed to
`exit()`) use the return value directly.

### Category 3: Intentional truncation (TOML parser)

The TOML parser reads lines up to 2048 bytes but stores keys/values in struct fields of 256 bytes.
This is correct behavior — TOML keys longer than 256 bytes are nonsensical for cpm.toml.

Wrap the parser function in a pragma block:

```cpp
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat-truncation"
int cpm_toml_parse(...) { ... }
#pragma GCC diagnostic pop
```

This is acceptable because:
- It's a single, well-documented location
- The truncation is the *correct* behavior (not a bug we're hiding)
- Adding `#ifdef __GNUC__` around it keeps MSVC clean

## Build verification

The Makefile build target must produce zero warnings. Add a CI check:

```makefile
warn-check: build
	@if make build 2>&1 | grep -q 'warning:'; then \
		echo "FAIL: compiler warnings detected"; exit 1; fi
```

## Consequences

- All source files that use raw `char buf[N]` for paths/commands must include `constants.h`.
- All fire-and-forget syscalls must use `CPM_DISCARD()`.
- CI blocks on any new warning (shift-left).
- ~30 lines of code change across 5 files. No logic changes, no behavior changes.
- Cross-platform: works on GCC, Clang, and MSVC.
