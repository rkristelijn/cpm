/**
// @see ADR-129
 * @file dangerous.cpp
 * @brief Native dangerous patterns check — eval(), ts-ignore, as any.
 */
#include "../check.h"

struct DangerousCheck : Check {
  DangerousCheck() {
    name = "dangerous";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|js)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;
        if (ln.find("eval(") != std::string::npos && ln.find("//") == std::string::npos)
          findings.push_back({name, "error", file, line, "eval", "eval() is a security risk", "Restructure logic without eval"});
        if (ln.find("@ts-ignore") != std::string::npos || ln.find("@ts-expect-error") != std::string::npos)
          findings.push_back({name, "warning", file, line, "ts-ignore", "@ts-ignore hides type errors", "Fix the type error"});
        if (ln.find(" as any") != std::string::npos)
          findings.push_back({name, "warning", file, line, "as-any", "'as any' defeats type safety", "Use proper type or unknown"});
        pos = eol + 1;
      }
    }
    return findings;
  }
};
