# check-windows-portability

`checks/universal/quality/check-windows-portability.sh`

Detects POSIX-only code in C/C++ files that will break on Windows.

## What it detects

| Pattern | Why it breaks |
|---------|--------------|
| `sys/wait.h` | Not available on Windows |
| `unistd.h` | Not available on MSVC |
| `fork()`, `pipe()`, `waitpid()` | POSIX process API, no Windows equivalent |
| `dup2()` | POSIX file descriptor API |
| `d_type`, `DT_DIR`, `DT_REG` | Not in Windows `dirent` struct |
| `WIFEXITED`, `WEXITSTATUS` | POSIX wait macros |
| `sigaction`, `kill()` | POSIX signal handling |

## Severity

warning

## Fix

Wrap POSIX code in `#ifdef _WIN32` / `#else` / `#endif` guards:

```c
#ifdef _WIN32
#include <windows.h>
// Windows implementation
#else
#include <sys/wait.h>
#include <unistd.h>
// POSIX implementation
#endif
```

Or use a compat header (see `src/common/compat.h` for reference).

## Auto-fix

Not available — requires manual platform-specific implementation.

## References

- Source: `checks/universal/quality/check-windows-portability.sh`
- Reference: `src/common/compat.h`
