/**
 * @file platform_posix.cpp
 * @brief Platform implementation for macOS and Linux (POSIX).
 *
 * The only permitted #ifdef in this file is __APPLE__ to distinguish
 * macOS (_NSGetExecutablePath) from Linux (/proc/self/exe).
 * All other POSIX APIs are identical across both platforms.
 *
 * Selected by the Makefile when OS != Windows_NT.
 * @see ADR-170
 */
#include "platform.h"

#include <cerrno>
#include <climits>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

namespace platform {

OsKind os_kind() {
#ifdef __APPLE__
  return OsKind::MacOS;
#else
  /* Distinguish Alpine (musl) from Debian/other at runtime. */
  if (FILE* f = fopen("/etc/alpine-release", "r")) {
    fclose(f);
    return OsKind::Alpine;
  }
  return OsKind::Linux;
#endif
}

std::string executable_path() {
#ifdef __APPLE__
  uint32_t sz = 0;
  _NSGetExecutablePath(nullptr, &sz);   // first call reports required size
  std::string buf(sz, '\0');
  if (_NSGetExecutablePath(buf.data(), &sz) != 0) return "";
  buf.resize(std::strlen(buf.c_str()));
  return buf;
#else
  std::string buf(PATH_MAX, '\0');
  auto len = readlink("/proc/self/exe", buf.data(), buf.size() - 1);
  if (len <= 0) return "";
  buf.resize(static_cast<size_t>(len));
  return buf;
#endif
}

std::string executable_dir() {
  std::string path = executable_path();
  auto slash = path.rfind('/');
  return (slash != std::string::npos) ? path.substr(0, slash) : ".";
}

double now_sec() {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec / 1e9;
}

int wait_exit(int raw_status) {
  if (WIFEXITED(raw_status)) return WEXITSTATUS(raw_status);
  return 1;
}

std::string cmd_which(const std::string& tool) {
  return "command -v " + tool + " >/dev/null 2>&1";
}

std::string cmd_version(const std::string& tool) {
  return tool + " --version 2>/dev/null | head -1";
}

std::string cmd_with_timeout(const std::string& cmd, int timeout_sec) {
  if (timeout_sec > 0) return "timeout " + std::to_string(timeout_sec) + " " + cmd + " 2>&1";
  return cmd + " 2>&1";
}

bool is_symlink(const std::string& path) {
  struct stat st;
  return lstat(path.c_str(), &st) == 0 && S_ISLNK(st.st_mode);
}

bool make_dir(const std::string& path) {
  if (path.empty()) return false;
  /* Create each parent segment in turn (mkdir -p semantics). EEXIST is fine. */
  std::string acc;
  for (size_t i = 0; i <= path.size(); i++) {
    if (i == path.size() || path[i] == '/') {
      if (i == 0) {
        acc += '/';  // absolute path root
        continue;
      }
      if (acc == "." || acc.empty()) {
        if (i < path.size()) acc += path[i];
        continue;
      }
      /* 0750: owner rwx, group r-x, no access for "others". Dropping the
       * world bits closes the Sonar file-permission finding without breaking
       * group-shared checkouts. @see SEC-044 */
      if (mkdir(acc.c_str(), 0750) != 0 && errno != EEXIST) return false;
    }
    if (i < path.size()) acc += path[i];
  }
  return true;
}

}  // namespace platform
