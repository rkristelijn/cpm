/**
 * @file complexity.cpp
 * @brief Native complexity check — detects god classes (>10 methods).
 */
#include "check.h"

struct ComplexityCheck : Check {
  int max_methods = 10;

  ComplexityCheck() { name = "complexity"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|cpp)$");
    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      std::string content = fs.read(file);
      int methods = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        /* Count function/method definitions */
        if (ln.find("async ") != std::string::npos || ln.find("public ") != std::string::npos
            || ln.find("private ") != std::string::npos || ln.find("static ") != std::string::npos) {
          if (ln.find("(") != std::string::npos) methods++;
        }
        pos = eol + 1;
      }
      if (methods > max_methods)
        findings.push_back({name, "warning", file, 0, "too-many-methods",
            std::to_string(methods) + " methods (max " + std::to_string(max_methods) + ")",
            "Split into smaller classes/modules"});
    }
    return findings;
  }
};
