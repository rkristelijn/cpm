/**
// @see ADR-129
 * @file tool_runner.cpp
 * @brief Real tool runner — executes commands via popen, captures output.
 */
#include "tool_runner.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

#ifdef _WIN32
#define popen _popen
#define pclose _pclose
#else
#include <sys/wait.h>
#include <unistd.h>
#endif

static int get_timeout() {
  const char* env = getenv("CPM_TIMEOUT");
  return env ? atoi(env) : 30;
}

bool RealToolRunner::has_tool(const std::string& name) {
#ifdef _WIN32
  std::string cmd = "where " + name + " >nul 2>&1";
#else
  std::string cmd = "command -v " + name + " >/dev/null 2>&1";
#endif
  return system(cmd.c_str()) == 0;
}

std::string RealToolRunner::tool_version(const std::string& name) {
#ifdef _WIN32
  std::string cmd = name + " --version 2>nul";
#else
  std::string cmd = name + " --version 2>/dev/null | head -1";
#endif
  FILE* p = popen(cmd.c_str(), "r");
  if (!p) return "";
  char buf[256];
  std::string result;
  while (fgets(buf, sizeof(buf), p)) result += buf;
  pclose(p);
  while (!result.empty() && result.back() == '\n') result.pop_back();
  return result;
}

ToolResult RealToolRunner::exec(const std::string& cmd) {
  ToolResult r{};
  int timeout = get_timeout();
#ifdef _WIN32
  std::string full = cmd + " 2>&1";
#else
  std::string full = timeout > 0 ? "timeout " + std::to_string(timeout) + " " + cmd + " 2>&1" : cmd + " 2>&1";
#endif
  FILE* p = popen(full.c_str(), "r");
  if (!p) {
    r.exit_code = 1;
    return r;
  }
  char buf[4096];
  while (fgets(buf, sizeof(buf), p)) r.stdout_str += buf;
  int status = pclose(p);
#ifdef _WIN32
  r.exit_code = status;
#else
  r.exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 1;
#endif
  return r;
}
