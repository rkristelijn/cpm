/**
 * @file compat.h
 * @brief Cross-platform compatibility shims for POSIX/Windows.
 */
#pragma once

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#include <process.h>
#define getcwd _getcwd
#define access _access
#define popen _popen
#define pclose _pclose
#define F_OK 0
#else
#include <unistd.h>
#endif

/**
 * Suppress GCC -Wunused-result for fire-and-forget calls.
 * @see ADR-160
 */
#ifdef __GNUC__
#define CPM_DISCARD(expr) do { __typeof__(expr) _r_ __attribute__((unused)) = (expr); (void)_r_; } while(0)
#else
#define CPM_DISCARD(expr) (void)(expr)
#endif
