# ADR-170: Multi-OS C++ Development — Platform Abstraction Strategy

**Status:** Accepted
**Date:** 2026-08-31
**Deciders:** @rkristelijn
**See also:** ADR-160 (zero-warnings policy), STYLE-012 (portability), STYLE-013, STYLE-014, STYLE-015, QUAL-078

## Context

cpm is a C++ binary that ships on macOS, Linux, and Windows. It uses platform-specific APIs in several places:

- **Executable path resolution** — `_NSGetExecutablePath` (macOS), `/proc/self/exe` (Linux), `GetModuleFileNameA` (Windows)
- **Process execution** — `popen`/`pclose` vs `_popen`/`_pclose`, `WIFEXITED`/`WEXITSTATUS` (POSIX-only)
- **Timing** — `clock_gettime(CLOCK_MONOTONIC)` vs `QueryPerformanceCounter`
- **Directory access** — `getcwd`, `access`, POSIX vs Win32
- **File permissions** — `F_OK`, `unistd.h` vs `io.h`/`direct.h`

A code scan (STYLE-013/014/015, QUAL-078) finds `#ifdef _WIN32` and `#ifdef __APPLE__` scattered across **8 source files**: `main.cpp`, `checks.cpp`, `runner.cpp`, `tool_runner.cpp`, `cmd_ops.cpp`, `scan.cpp`, `scan_lang.cpp`, `scan_universal.cpp`. The same executable-path block (`_NSGetExecutablePath`) is duplicated in both `main.cpp` (3×) and `checks.cpp` (1×).

This is **platform logic leaking into business logic**. The C++ Core Guidelines (I.4, CP.4) and CppCon 2023 ("Abstraction Patterns for Cross Platform Development" — Al-Afiq Yeong) are consistent: platform divergence belongs at the boundary, not scattered through application code.

### Three options discussed in the community

The Reddit r/cpp_questions discussion (2021) and CppCon 2023 identify three approaches:

| Pattern | Runtime cost | Complexity | Use case |
|---------|-------------|------------|----------|
| Virtual base class + factory | vtable overhead + heap | High | Runtime-selectable backends (game engines, plugin systems) |
| PIMPL | heap allocation + indirection | Medium | ABI-stable shared libraries |
| Compile-time selection | Zero | Low | Platform known at compile time |

**Virtual dispatch and PIMPL are solutions for a different problem.** They solve *runtime* selection between interchangeable implementations. cpm's platform is fixed at compile time — building for macOS produces a macOS binary. There is no runtime choice. Applying runtime polymorphism here adds overhead and complexity for zero benefit.

The correct pattern for compile-time platform selection is: **separate translation units per platform, selected by the build system.**

This is what LLVM (`lib/Support/Unix/` vs `lib/Support/Windows/`), CMake (`Source/kwsys/`), libuv (`src/unix/` vs `src/win/`), and Chromium (`base/*_posix.cc` vs `base/*_win.cc`) all do. One interface header, per-platform `.cpp` files, the build system picks the right one.

### Current state of `compat.h`

`compat.h` exists and handles simple name shims correctly:

- `getcwd`, `access`, `popen`, `pclose`, `F_OK` (Win32 name differences)
- `localtime_r` (Windows lacks POSIX version)
- `CPM_DISCARD` macro (GCC vs others)

This is correct and stays. The gap is **behaviorally divergent code** — `_NSGetExecutablePath`/`GetModuleFileNameA`/`/proc/self/exe`, `WIFEXITED`/`WEXITSTATUS`, `QueryPerformanceCounter` vs `clock_gettime` — which requires actual implementation differences, not just name aliases. That code must not live in business logic files.

### The boundary rule

```text
Name alias (1 line, no logic)     → compat.h            (stays as-is)
Behaviorally divergent (>1 line)  → platform_posix.cpp
                                    platform_win32.cpp   (new, selected by Makefile)
```

macOS and Linux share `platform_posix.cpp` — they are both POSIX. The one macOS-specific call (`_NSGetExecutablePath` vs `/proc/self/exe`) lives inside that file behind a single `#ifdef __APPLE__`. That is the only permitted location for that guard in the entire codebase.

## Decision

### Pattern: Compile-Time Platform Abstraction via Translation Unit Selection

Two files implement the same interface (`platform.h`), and the Makefile selects which one to compile:

```text
src/common/platform.h           ← interface (always compiled, included everywhere)
src/common/platform_posix.cpp   ← macOS + Linux implementation
src/common/platform_win32.cpp   ← Windows implementation
```

Makefile selection (using existing `RE2_SRCS` pattern already in the codebase):

```makefile
ifeq ($(OS),Windows_NT)
  PLATFORM_SRC = src/common/platform_win32.cpp
else
  PLATFORM_SRC = src/common/platform_posix.cpp
endif

SRCS = ... $(PLATFORM_SRC)
```

### Interface (`platform.h`)

```cpp
// src/common/platform.h
// @see ADR-170
#pragma once
#include <string>

namespace platform {

  /// Absolute path to the running executable.
  /// posix: _NSGetExecutablePath (macOS) or /proc/self/exe (Linux)
  /// win32: GetModuleFileNameA
  std::string executable_path();

  /// Directory containing the running executable (no trailing slash).
  std::string executable_dir();

  /// Monotonic high-resolution time in seconds.
  /// posix: clock_gettime(CLOCK_MONOTONIC)
  /// win32: QueryPerformanceCounter
  double now_sec();

  /// Decode raw system() exit status to an exit code.
  /// posix: WIFEXITED / WEXITSTATUS  win32: direct return value
  int wait_exit(int raw_status);

}  // namespace platform
```

### POSIX implementation (`platform_posix.cpp`)

```cpp
// src/common/platform_posix.cpp
// @see ADR-170
#include "platform.h"
#include <string>
#include <climits>
#include <cstring>
#include <time.h>
#include <sys/wait.h>
#include <unistd.h>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

namespace platform {

std::string executable_path() {
  char buf[PATH_MAX] = "";
#ifdef __APPLE__
  uint32_t sz = static_cast<uint32_t>(sizeof(buf));
  _NSGetExecutablePath(buf, &sz);
#else
  auto len = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
  if (len > 0) buf[len] = '\0';
#endif
  return buf;
}

std::string executable_dir() {
  std::string path = executable_path();
  auto slash = path.rfind('/');
  return (slash != std::string::npos) ? path.substr(0, slash) : ".";
}

double now_sec() {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec * 1e-9;
}

int wait_exit(int raw_status) {
  if (WIFEXITED(raw_status)) return WEXITSTATUS(raw_status);
  return 1;
}

}  // namespace platform
```

### Windows implementation (`platform_win32.cpp`)

```cpp
// src/common/platform_win32.cpp
// @see ADR-170
#include "platform.h"
#include <string>
#include <windows.h>

namespace platform {

std::string executable_path() {
  char buf[MAX_PATH] = "";
  GetModuleFileNameA(NULL, buf, sizeof(buf));
  return buf;
}

std::string executable_dir() {
  std::string path = executable_path();
  auto slash = path.rfind('\\');
  if (slash == std::string::npos) slash = path.rfind('/');
  return (slash != std::string::npos) ? path.substr(0, slash) : ".";
}

double now_sec() {
  LARGE_INTEGER freq, count;
  QueryPerformanceFrequency(&freq);
  QueryPerformanceCounter(&count);
  return static_cast<double>(count.QuadPart) / freq.QuadPart;
}

int wait_exit(int raw_status) {
  return raw_status;  // system() returns exit code directly on Windows
}

}  // namespace platform
```

### Permitted `#ifdef` locations after this change

| Location | Permitted guards | Reason |
|----------|-----------------|--------|
| `src/common/compat.h` | `_WIN32`, `__GNUC__` | Name shims + trivial constants (setenv, strcasestr, popen, CPM_PATH_SEP) |
| `src/common/platform_posix.cpp` | `__APPLE__` | macOS vs Linux within POSIX |
| `src/common/platform_win32.cpp` | `_WIN32` | Already implicitly Windows-only |
| `src/common/runner_posix.cpp` | none | POSIX execution engine (fork/pipe/waitpid), Makefile-selected |
| `src/common/runner_win32.cpp` | none | Windows execution engine (sequential system()), Makefile-selected |
| `vendor/` | anything | Third-party code, not our responsibility |
| Everywhere else | **none** | Violation → STYLE-013/014/015, QUAL-078 |

The execution engine (`cpm_run_parallel`) was split the same way as `platform.*`:
`runner.cpp` keeps the platform-agnostic helpers (expressed through `platform::`),
while the fork-based (POSIX) and sequential (Windows) implementations live in
`runner_posix.cpp` / `runner_win32.cpp`, selected by the Makefile's `PLATFORM_SRC`.
This mirrors libuv's `src/unix/` vs `src/win/` split.

### Platform interface (final)

Beyond the original four functions, the shell-command shape also diverges by OS
(`where` vs `command -v`, `>nul` vs `>/dev/null`, timeout utility availability).
These are adapted through `platform::` rather than scattered `#ifdef`s:

| Function | POSIX | Windows |
|----------|-------|---------|
| `os_kind()` | MacOS / Linux / Alpine (runtime `/etc/alpine-release`) | Windows |
| `cmd_which(tool)` | `command -v tool >/dev/null 2>&1` | `where tool >nul 2>&1` |
| `cmd_version(tool)` | `tool --version 2>/dev/null \| head -1` | `tool --version 2>nul` |
| `cmd_with_timeout(cmd,n)` | `timeout n cmd 2>&1` | `cmd 2>&1` (no timeout util) |

`os_kind()` replaces the `detect_platform()` `#ifdef` ladder in `setup.cpp`;
the `cmd_*` adapters keep `runner.cpp` and `tool_runner.cpp` `#ifdef`-free.

## Implementation Plan

This is a pure refactor — no behavior changes, no new features. The test suite verifies correctness throughout.

### Step 1 — Create `platform.h`, `platform_posix.cpp`, `platform_win32.cpp`

Create the three files as specified above. The implementations are direct extractions from existing code — no new logic.

Verify: `make build` passes on macOS and Linux.

### Step 2 — Wire into Makefile

```makefile
# Platform source selection — @see ADR-170
ifeq ($(OS),Windows_NT)
  PLATFORM_SRC = src/common/platform_win32.cpp
else
  PLATFORM_SRC = src/common/platform_posix.cpp
endif

SRCS = src/main.cpp src/commands/commands.cpp src/commands/cmd_ops.cpp \
       src/commands/cmd_sort.cpp src/checks.cpp src/common/ui.cpp     \
       src/common/toml.cpp src/common/runner.cpp src/common/setup.cpp \
       src/scan/scan.cpp src/scan/scan_checks.cpp src/scan/scan_classify.cpp \
       src/scan/scan_lang.cpp src/scan/scan_ci.cpp src/scan/scan_universal.cpp \
       $(PLATFORM_SRC) $(RE2_SRCS)
```

Verify: `make build` still passes.

### Step 3 — Refactor `src/main.cpp` (3 duplication sites)

Replace all three `#ifdef __APPLE__ / _NSGetExecutablePath` blocks:

```cpp
// Before (repeated 3× in main.cpp):
char bin_dir[CPM_PATH_MAX] = "";
#ifdef __APPLE__
  uint32_t sz = static_cast<uint32_t>(sizeof(bin_dir));
  _NSGetExecutablePath(bin_dir, &sz);
#else
  auto len = readlink("/proc/self/exe", bin_dir, sizeof(bin_dir) - 1);
  if (len > 0) bin_dir[len] = '\0';
#endif
// ... then strrchr(bin_dir, '/') to get the dir

// After:
#include "common/platform.h"
std::string bin_dir = platform::executable_dir();
```

Remove `#include <mach-o/dyld.h>` and `#include <windows.h>` from `main.cpp`.

Verify: `make test` passes.

### Step 4 — Refactor `src/checks.cpp` (1 duplication site)

Same pattern as step 3 — one occurrence of `_NSGetExecutablePath`.

```cpp
// Before:
char bin_path[CPM_PATH_MAX] = "";
#ifdef __APPLE__
  uint32_t sz = static_cast<uint32_t>(sizeof(bin_path));
  _NSGetExecutablePath(bin_path, &sz);
#elif defined(_WIN32)
  GetModuleFileNameA(NULL, bin_path, sizeof(bin_path));
#else
  auto len = readlink("/proc/self/exe", bin_path, sizeof(bin_path) - 1);
  if (len > 0) bin_path[len] = '\0';
#endif

// After:
std::string bin_path = platform::executable_path();
```

Verify: `make test` passes.

### Step 5 — Refactor `src/common/runner.cpp`

`runner.cpp` has two platform issues:

1. `static double now_sec()` — inline function that duplicates platform detection
2. `WIFEXITED`/`WEXITSTATUS` calls at 3 sites (lines 74, 215, 228)

```cpp
// Before (now_sec static function in runner.cpp):
static double now_sec(void) {
#ifdef _WIN32
  LARGE_INTEGER freq, count;
  QueryPerformanceFrequency(&freq);
  QueryPerformanceCounter(&count);
  return static_cast<double>(count.QuadPart) / freq.QuadPart;
#else
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec * 1e-9;
#endif
}

// After: delete the static function, add include, use platform::now_sec()
#include "platform.h"
// all calls to now_sec() become platform::now_sec()

// Before (WIFEXITED sites):
s.results[i].exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 1;

// After:
s.results[i].exit_code = platform::wait_exit(status);
```

Verify: `make test` passes.

### Step 6 — Refactor remaining files

Remaining `#ifdef _WIN32` blocks in `tool_runner.cpp`, `cmd_ops.cpp`, `scan.cpp`, `scan_lang.cpp`, `scan_universal.cpp` — audit each one:

- If it fits an existing `platform::` function → replace
- If it needs a new abstraction → add to `platform.h` + both `.cpp` files first, then replace
- If it is a name shim already covered by `compat.h` → verify `compat.h` is included and remove the local guard

Verify: `make test` and `cpm check --full` pass. The rules STYLE-013/014/015/QUAL-078 should report zero findings on `src/` (excluding `src/common/`).

### Step 7 — Verify rule coverage

```bash
cpm check --full   # must pass clean on the refactored code
```

Expected: STYLE-013, STYLE-014, STYLE-015, QUAL-078 produce zero findings outside `src/common/`.

### Acceptance criteria

- [ ] `src/common/platform.h` exists with the four function declarations
- [ ] `src/common/platform_posix.cpp` and `platform_win32.cpp` exist
- [ ] Makefile selects the correct file via `PLATFORM_SRC`
- [ ] `#ifdef __APPLE__` and `#ifdef _WIN32` appear **only** in `src/common/`
- [ ] `make test` passes (all existing tests green)
- [ ] `cpm check --full` passes (STYLE-013/014/015/QUAL-078 zero findings outside `src/common/`)
- [ ] CI green on macOS and Linux runners

## Rationale

### Why separate translation units, not a single `platform.cpp` with `#ifdef`?

A single `platform.cpp` with `#ifdef __APPLE__ / _WIN32 / __linux__` inside each function still works, but it has a subtle problem: the compiler parses and type-checks all branches on every platform. Dead code in the wrong branch can silently accumulate errors that only manifest when building on the other platform. Separate translation units mean the Windows-only code never touches the macOS compiler and vice versa — you get a hard build failure on the platform that matters, not a latent surprise.

This is why libuv, LLVM, and Chromium use separate files. It is also why the Makefile already uses this pattern for RE2 (`RE2_SRCS` is conditionally set).

### Why not PIMPL or virtual dispatch?

PIMPL (Pointer to Implementation) and abstract base classes with virtual methods solve runtime selection — multiple implementations active simultaneously, selected at runtime. cpm builds one binary per platform. The platform is a compile-time constant. Applying runtime selection machinery here is the wrong level of abstraction.

Concretely: PIMPL adds a heap allocation and an indirection for every `platform::executable_path()` call. A free function in a translation unit adds zero overhead. The CppCon 2023 talk ("Abstraction Patterns for Cross Platform Development") categorizes this as the difference between *platform abstraction* (our case) and *backend abstraction* (game engine APIs, database drivers). These require different patterns.

### Why macOS and Linux share one file?

macOS is a POSIX system. The APIs differ only at one point: `_NSGetExecutablePath` vs `/proc/self/exe`. Everything else — `WIFEXITED`, `clock_gettime`, `popen` — is identical. A single `platform_posix.cpp` with one `#ifdef __APPLE__` is cleaner than three separate files. If macOS divergence grows, extract `platform_macos.cpp` then.

### Why `namespace platform`?

- Signals intent — "this is the OS boundary"
- Enables exact grep: `grep "platform::"` finds every call site
- Avoids collisions (`now_sec` is generic)
- Consistent with LLVM (`llvm::sys::`), libuv (`uv_`), Qt (`QSysInfo::`)

## Consequences

### Positive

- `#ifdef __APPLE__` and `#ifdef _WIN32` eliminated from 8 business logic files
- `_NSGetExecutablePath` duplication (4 sites → 1) resolved permanently
- Business logic becomes platform-agnostic and fully unit-testable
- Adding a fourth platform (FreeBSD, WASM) requires one new file: `platform_freebsd.cpp` + one Makefile line
- STYLE-013/014/015/QUAL-078 enforce the boundary automatically at every commit
- Consistent with how RE2 conditional compilation is already done in the Makefile

### Spin-off: generic duplicate-symbol detection

While refactoring, the same portability shim (`strcasestr`) was found copy-pasted
across two scan files. A hardcoded rule for known shim names was considered and
**rejected** — it would only work on cpm itself, not on arbitrary scanned repos.

Instead, a language-agnostic **duplicate-symbol check** was built
(`src/analysis/dup_symbols.{h,cpp}`): it extracts every function/file-scope
definition, normalizes the body (comments/strings/whitespace/operator-spacing
removed via the tokenizer), and reports any body that appears byte-identical in
two or more files. No hardcoded names — it catches the `strcasestr` case (and any
future copy-paste) generically. Warning severity; suppressible via
`[checks] dup-symbols.enabled = false`.

It is structured as an explicit Unix-style pipeline so it can migrate into the
declarative rule engine once that grows composable operators (ADR-166 follow-up):

```
extract_symbols | normalize_body | group_by(hash) | filter(count>1, files>=2) | report
```

At that point the C++ check becomes a `.rule` definition with no behaviour change.
Kept separate from ADR-170's scope but documented here as its origin.

### Negative

- One-time refactor effort (~2h across 8 files)
- Two new files to maintain (`platform_posix.cpp`, `platform_win32.cpp`) — Windows branch cannot be tested without a Windows build
- The `#ifdef __APPLE__` inside `platform_posix.cpp` is still a preprocessor guard — just in the right place

### Neutral

- `compat.h` unchanged — shims stay as shims
- No runtime behavior changes — pure structural refactor
- `vendor/` excluded from all rules

## Alternatives Considered

### A: Single `platform.cpp` with inline `#ifdef` per function

Simpler (one file instead of two), but all three platform branches are compiled on every platform. Dead code accumulates undetected. Rejected in favor of separate translation units.

### B: Abstract base class (`IPlatform`) + factory

Correct solution for runtime-selectable backends. Wrong tool for compile-time platform selection. Adds vtable, heap allocation, virtual call overhead. Rejected — wrong abstraction level.

### C: PIMPL idiom

Correct for ABI-stable shared libraries. cpm is a statically linked CLI binary, not a library. Rejected — wrong use case.

### D: Leave `#ifdef` scattered, just document it

Works today. Fails silently over time: duplication, untestable business logic, O(n) cost per new platform. Rejected — ADR-160 (zero warnings) and cpm's own quality checks would flag this.

### E: `std::filesystem` everywhere, ban all `#ifdef`

`std::filesystem` covers path manipulation. It does not cover executable path resolution, high-res monotonic timers, or process exit status decoding. `#ifdef` remains necessary — the goal is to confine it, not eliminate it.

### F: Import an existing portable-runtime library (APR / libuv / Boost / Qt / abseil)

The "one OS layer with all the tricks in it" already exists as mature, battle-tested libraries — think of them as a *jQuery for C/C++*, and our hand-written `platform.h` as the small amount of native code you write once jQuery is overkill:

| Library | Scope | Analogy |
|---------|-------|---------|
| **APR** (Apache Portable Runtime) | files, processes, time, sockets, mmap — the classic C "OS plugin" | jQuery core |
| **libuv** | async I/O + platform abstraction (powers Node.js) | jQuery events/async |
| **Boost** (`.Process`, `.Filesystem`, `.Chrono`) | per-domain C++ portability | a plugin collection |
| **Qt Core** (`QProcess`, `QSysInfo`) | full cross-platform runtime | jQuery UI (all-in-one) |
| **abseil** | Google's portability layer | the modern successor |

These are the right choice when a project needs *dozens* of platform primitives — importing a tested wheel beats reinventing it. cpm is rejected from this path for three reasons:

1. **Zero-dependency is a core product promise.** The README states "one binary, zero runtime dependencies." Linking APR/Qt/Boost means a heavier binary, extra build/CI complexity on every platform, and a supply-chain surface — for **8 small functions**. Cannon, meet mosquito.
2. **Modern C++ already covers most of it** (the jQuery→`querySelector` effect). `std::filesystem` (paths), `std::chrono` (timers), `std::thread` (concurrency). What remains — executable-path resolution, `system()` exit decoding, shell-command shape (`where` vs `command -v`) — is precisely the handful the standard does *not* cover. Not framework-worthy.
3. **This ADR chose "confine, don't import."** The goal is to *isolate* platform divergence in one place, not delegate it to an external runtime. `platform.h` **is** that OS layer — a purpose-built micro-runtime (a "micro-APR") sized exactly to what cpm touches.

Reassessment trigger: if cpm ever needs ~50+ platform primitives (async networking, IPC, memory mapping), revisit this — at that scale importing libuv or APR becomes defensible. At ~8 functions the dependency cost outweighs the benefit. Rejected for now, documented so the question need not be re-litigated.
