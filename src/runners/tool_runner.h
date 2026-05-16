/**
 * @file tool_runner.h
 * @brief Mockable tool execution interface — all external tool calls go through this.
 */
#ifndef CPM_RUNNERS_TOOL_RUNNER_H
#define CPM_RUNNERS_TOOL_RUNNER_H

#include <string>

struct ToolResult {
  int exit_code;
  std::string stdout_str;
  std::string stderr_str;
};

struct ToolRunner {
  virtual ~ToolRunner() = default;
  virtual bool has_tool(const std::string& name) = 0;
  virtual std::string tool_version(const std::string& name) = 0;
  virtual ToolResult exec(const std::string& cmd) = 0;
};

/** @brief Real tool runner — executes via popen(). */
struct RealToolRunner : ToolRunner {
  bool has_tool(const std::string& name) override;
  std::string tool_version(const std::string& name) override;
  ToolResult exec(const std::string& cmd) override;
};

/** @brief Mock tool runner — returns preset results for testing. */
struct MockToolRunner : ToolRunner {
  int mock_exit = 0;
  std::string mock_stdout;
  bool has_tool(const std::string&) override { return true; }
  std::string tool_version(const std::string&) override { return "1.0.0"; }
  ToolResult exec(const std::string&) override { return {mock_exit, mock_stdout, ""}; }
};

#endif
