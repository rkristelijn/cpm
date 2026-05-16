/**
 * @file tool_runner.cpp
 * @brief Real tool runner — executes commands via popen, captures output.
 */
#include "tool_runner.h"

#include <cstdio>
#include <cstring>

bool RealToolRunner::has_tool(const std::string& name) {
  std::string cmd = "command -v " + name + " >/dev/null 2>&1";
  return system(cmd.c_str()) == 0;
}

std::string RealToolRunner::tool_version(const std::string& name) {
  std::string cmd = name + " --version 2>/dev/null | head -1";
  FILE* p = popen(cmd.c_str(), "r");
  if (!p) return "";
  char buf[256];
  std::string result;
  while (fgets(buf, sizeof(buf), p)) result += buf;
  pclose(p);
  /* Strip trailing newline */
  while (!result.empty() && result.back() == '\n') result.pop_back();
  return result;
}

ToolResult RealToolRunner::exec(const std::string& cmd) {
  ToolResult r{};
  std::string full = cmd + " 2>&1";
  FILE* p = popen(full.c_str(), "r");
  if (!p) { r.exit_code = 1; return r; }
  char buf[4096];
  while (fgets(buf, sizeof(buf), p)) r.stdout_str += buf;
  int status = pclose(p);
  r.exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 1;
  return r;
}
