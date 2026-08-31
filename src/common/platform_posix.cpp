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

#include <climits>
#include <cstring>
#include <string>
#include <sys/time.h>
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
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  return tv.tv_sec + tv.tv_usec / 1e6;
}

int wait_exit(int raw_status) {
  if (WIFEXITED(raw_status)) return WEXITSTATUS(raw_status);
  return 1;
}

}  // namespace platform
