/**
 * @file todo.cpp
 * @brief Native TODO/FIXME/HACK extraction — tracks technical debt.
 */
#include "check.h"

#include <regex>

struct TodoCheck : Check {
  TodoCheck() { name = "todo"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    static const std::regex pattern("\\b(TODO|FIXME|HACK|XXX)\\b(.*)");

    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py|sh|tf|php)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        line++;
        std::string ln = content.substr(pos, eol - pos);
        std::smatch m;
        if (std::regex_search(ln, m, pattern)) {
          findings.push_back({name, "info", file, line, "technical-debt",
              m[1].str() + m[2].str(), ""});
        }
        pos = eol + 1;
      }
    }
    return findings;
  }
};
