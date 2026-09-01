/**
 * @file platform.h
 * @brief Platform abstraction layer — compile-time selection via translation units.
 *
 * Declare platform-divergent functions here. Implementations live in:
 *   platform_posix.cpp  — macOS + Linux
 *   platform_win32.cpp  — Windows
 *
 * The Makefile selects the correct .cpp via PLATFORM_SRC.
 * Business logic must NEVER include <mach-o/dyld.h>, <windows.h>, or
 * call _NSGetExecutablePath/GetModuleFileNameA/WIFEXITED directly.
 *
 * @see ADR-170
 */
#pragma once
#include <string>

namespace platform {

/// Coarse OS family, for logic that must branch on the platform
/// (e.g. package-manager selection) without scattering #ifdefs.
enum class OsKind { MacOS, Linux, Alpine, Windows, Unknown };

/// The OS this binary was built for. On Linux, distinguishes Alpine at runtime.
OsKind os_kind();

/// Absolute path to the running executable.
/// posix: _NSGetExecutablePath (macOS) or /proc/self/exe (Linux)
/// win32: GetModuleFileNameA
std::string executable_path();

/// Directory containing the running executable (no trailing slash).
std::string executable_dir();

/// Monotonic high-resolution time in seconds.
/// posix: clock_gettime(CLOCK_MONOTONIC)   win32: QueryPerformanceCounter
double now_sec();

/// Decode raw system() / waitpid() exit status to a plain exit code.
/// posix: WIFEXITED / WEXITSTATUS   win32: direct return value
int wait_exit(int raw_status);

/// Shell command that tests whether a tool is on PATH (exit 0 = found).
/// posix: command -v <tool> >/dev/null 2>&1   win32: where <tool> >nul 2>&1
std::string cmd_which(const std::string& tool);

/// Shell command that prints a tool's version (single line).
/// posix: <tool> --version 2>/dev/null | head -1   win32: <tool> --version 2>nul
std::string cmd_version(const std::string& tool);

/// Wrap a command with a timeout (seconds) and stderr redirect.
/// posix: timeout <n> <cmd> 2>&1 (when n>0)   win32: <cmd> 2>&1 (no timeout util)
std::string cmd_with_timeout(const std::string& cmd, int timeout_sec);

/// True if `path` is a symbolic link (not followed).
/// posix: lstat + S_ISLNK   win32: false (no POSIX symlink loops to guard)
bool is_symlink(const std::string& path);

/// Create `path` and any missing parent directories (like `mkdir -p`).
/// Idempotent: succeeds if the directory already exists.
/// posix: mkdir() per path segment   win32: CreateDirectoryA per segment
/// @return true on success (or already-exists), false on real failure.
bool make_dir(const std::string& path);

}  // namespace platform
