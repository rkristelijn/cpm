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
/* Windows lacks POSIX localtime_r. Use thread-unsafe localtime + copy. */
#include <ctime>
static inline struct tm* localtime_r(const time_t* t, struct tm* buf) {
  struct tm* result = localtime(t);
  if (result) { *buf = *result; return buf; }
  return nullptr;
}
/* Windows lacks POSIX setenv. Emulate with _putenv_s. */
#include <cstdlib>
static inline int setenv(const char* name, const char* value, int overwrite) {
  if (!overwrite && getenv(name)) return 0;
  return _putenv_s(name, value);
}
/* strcasestr is a GNU extension, absent on Windows. Portable fallback. */
#include <cctype>
#include <cstring>
static inline const char* strcasestr(const char* haystack, const char* needle) {
  if (!needle[0]) return haystack;
  for (; *haystack; haystack++) {
    const char* h = haystack;
    const char* n = needle;
    while (*h && *n && (tolower((unsigned char)*h) == tolower((unsigned char)*n))) {
      h++;
      n++;
    }
    if (!*n) return haystack;
  }
  return nullptr;
}
static constexpr char CPM_PATH_SEP = '\\';
#else
#include <unistd.h>
static constexpr char CPM_PATH_SEP = '/';
#endif

/**
 * Suppress GCC -Wunused-result for fire-and-forget calls.
 * @see ADR-160
 */
#ifdef __GNUC__
#define CPM_DISCARD(expr)                                  \
  do {                                                     \
    __typeof__(expr) _r_ __attribute__((unused)) = (expr); \
    (void)_r_;                                             \
  } while (0)
#else
#define CPM_DISCARD(expr) (void)(expr)
#endif
