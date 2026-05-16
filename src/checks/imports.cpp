/**
 * @file imports.cpp
 * @brief Native import check — detects deep relative imports in TypeScript.
 */
#include "check.h"

struct ImportsCheck : Check {
  ImportsCheck() { name = "imports"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.ts$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;
        if (ln.find("../../../") != std::string::npos && ln.find("import") != std::string::npos)
          findings.push_back({name, "warning", file, line, "deep-import",
              "Deep relative import (3+ levels)", "Use path alias @/"});
        pos = eol + 1;
      }
    }
    return findings;
  }
};
