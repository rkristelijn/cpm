/**
 * @file platform_win32.cpp
 * @brief Platform implementation for Windows (Win32).
 *
 * No #ifdef guards needed — this file is only compiled on Windows.
 * Selected by the Makefile when OS == Windows_NT.
 * @see ADR-170
 */
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
