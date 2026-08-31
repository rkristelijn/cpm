/**
// @see ADR-129
 * @file tool_runner.cpp
 * @brief Real tool runner — executes commands via popen, captures output.
 */
#include "tool_runner.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "../common/compat.h"
#include "../common/platform.h"

static int get_timeout() {
  const char* env = getenv("CPM_TIMEOUT");
  return env ? atoi(env) : 30;
}

bool RealToolRunner::has_tool(const std::string& name) {
  return system(platform::cmd_which(name).c_str()) == 0;
}

std::string RealToolRunner::tool_version(const std::string& name) {
  FILE* p = popen(platform::cmd_version(name).c_str(), "r");
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
  std::string full = platform::cmd_with_timeout(cmd, get_timeout());
  FILE* p = popen(full.c_str(), "r");
  if (!p) {
    r.exit_code = 1;
    return r;
  }
  char buf[4096];
  while (fgets(buf, sizeof(buf), p)) r.stdout_str += buf;
  r.exit_code = platform::wait_exit(pclose(p));
  return r;
}
