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

/// Absolute path to the running executable.
/// posix: _NSGetExecutablePath (macOS) or /proc/self/exe (Linux)
/// win32: GetModuleFileNameA
std::string executable_path();

/// Directory containing the running executable (no trailing slash).
std::string executable_dir();

/// Monotonic high-resolution time in seconds.
/// posix: gettimeofday   win32: QueryPerformanceCounter
double now_sec();

/// Decode raw system() / waitpid() exit status to a plain exit code.
/// posix: WIFEXITED / WEXITSTATUS   win32: direct return value
int wait_exit(int raw_status);

}  // namespace platform
