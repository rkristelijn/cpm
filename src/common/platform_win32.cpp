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

OsKind os_kind() { return OsKind::Windows; }

std::string executable_path() {
  std::string buf(MAX_PATH, '\0');
  for (;;) {
    DWORD len = GetModuleFileNameA(NULL, buf.data(), static_cast<DWORD>(buf.size()));
    if (len == 0) return "";
    // Truncated: ERROR_INSUFFICIENT_BUFFER → len == buf.size(). Grow and retry.
    if (len < buf.size()) {
      buf.resize(len);
      return buf;
    }
    buf.resize(buf.size() * 2);
  }
}

std::string executable_dir() {
  std::string path = executable_path();
  auto slash = path.rfind('\\');
  if (slash == std::string::npos) slash = path.rfind('/');
  if (slash == std::string::npos) return ".";
  // Preserve trailing separator for a drive root ("C:\\foo.exe" → "C:\\").
  if (slash >= 2 && path[slash - 1] == ':') return path.substr(0, slash + 1);
  return path.substr(0, slash);
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

std::string cmd_which(const std::string& tool) {
  return "where " + tool + " >nul 2>&1";
}

std::string cmd_version(const std::string& tool) {
  return tool + " --version 2>nul";
}

std::string cmd_with_timeout(const std::string& cmd, int /*timeout_sec*/) {
  return cmd + " 2>&1";  // no portable timeout utility on Windows
}

bool is_symlink(const std::string& /*path*/) {
  return false;  // Windows dir walking does not hit POSIX symlink loops here
}

bool make_dir(const std::string& path) {
  if (path.empty()) return false;
  /* Create each segment in turn; both '/' and '\\' act as separators.
   * ERROR_ALREADY_EXISTS is treated as success (mkdir -p semantics). */
  std::string acc;
  for (size_t i = 0; i <= path.size(); i++) {
    if (i == path.size() || path[i] == '/' || path[i] == '\\') {
      /* Skip empty, ".", and a bare drive spec like "C:". */
      if (!acc.empty() && acc != "." && !(acc.size() == 2 && acc[1] == ':')) {
        if (!CreateDirectoryA(acc.c_str(), nullptr) && GetLastError() != ERROR_ALREADY_EXISTS) return false;
      }
    }
    if (i < path.size()) acc += path[i];
  }
  return true;
}

}  // namespace platform
