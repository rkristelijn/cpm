/**
 * @file portability.cpp
 * @brief Native portability check — detects platform-specific issues.
 */
#include "check.h"

struct PortabilityCheck : Check {
  PortabilityCheck() { name = "portability"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    auto files = fs.find_files("src", "\\.(cpp|h)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        /* Hardcoded path separator */
        if (ln.find("+ \"/\"") != std::string::npos || ln.find("+ \"\\\\\"") != std::string::npos)
          findings.push_back({name, "warning", file, line, "hardcoded-path-sep",
              "Hardcoded path separator", "Use PATH_SEP constant"});

        /* Platform-specific headers without guard */
        if ((ln.find("conio.h") != std::string::npos || ln.find("direct.h") != std::string::npos)
            && ln.find("#ifdef") == std::string::npos && ln.find("#if") == std::string::npos)
          findings.push_back({name, "warning", file, line, "platform-header",
              "Platform-specific header without #ifdef guard", ""});

        pos = eol + 1;
      }
    }
    return findings;
  }
};
