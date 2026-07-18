/**
// @see ADR-129
 * @file dangerous.cpp
 * @brief Native dangerous patterns check — eval(), ts-ignore, as any.
 */
#include "../check.h"

#include "../../line_scanner.h"

struct DangerousCheck : Check {
  DangerousCheck() {
    name = "dangerous";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    scan_lines(fs, "src", "\\.(ts|js)$", [&](const std::string& file, int line, const std::string& ln) {
      if (ln.find("eval(") != std::string::npos && ln.find("//") == std::string::npos)
        findings.push_back({name, "error", file, line, "eval", "eval() is a security risk", "Restructure logic without eval"});
      if (ln.find("@ts-ignore") != std::string::npos || ln.find("@ts-expect-error") != std::string::npos)
        findings.push_back({name, "warning", file, line, "ts-ignore", "@ts-ignore hides type errors", "Fix the type error"});
      if (ln.find(" as any") != std::string::npos)
        findings.push_back({name, "warning", file, line, "as-any", "'as any' defeats type safety", "Use proper type or unknown"});
    });
    return findings;
  }
};
