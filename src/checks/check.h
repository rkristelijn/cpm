/**
 * @file check.h
 * @brief Check interface — all quality checks implement this.
 *
 * A Check receives mockable FileSystem + ToolRunner, returns Findings.
 * This enables unit testing without real files or tools.
 */
#ifndef CPM_CHECKS_CHECK_H
#define CPM_CHECKS_CHECK_H

#include <string>
#include <vector>

#include "../io/filesystem.h"
#include "../runners/tool_runner.h"

/** @brief A single quality finding (error, warning, or info). */
struct Finding {
  std::string check;    /* "secrets-fast" */
  std::string severity; /* "error" | "warning" | "info" */
  std::string file;     /* "src/main.cpp" */
  int line = 0;         /* 42 */
  std::string rule;     /* "hardcoded-secret" */
  std::string message;  /* "Potential API key detected" */
  std::string fix;      /* "Use environment variable" */
  std::string docs;     /* "https://cpm.dev/checks/secrets" */
  double duration = 0;  /* seconds this check took */
};

/** @brief Base class for all checks. */
struct Check {
  const char* name;
  const char* category; /* "security", "quality", "style", "deps" */

  virtual ~Check() = default;
  virtual std::vector<Finding> run(FileSystem& fs, ToolRunner& runner) = 0;
};

#endif
