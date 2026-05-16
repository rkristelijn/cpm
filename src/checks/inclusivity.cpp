/**
 * @file inclusivity.cpp
 * @brief Native inclusivity check — flags non-inclusive terminology.
 */
#include "check.h"

#include <regex>

struct InclusivityCheck : Check {
  InclusivityCheck() { name = "inclusivity"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    /* Non-inclusive terms and their replacements */
    static const struct { const char* term; const char* replacement; } terms[] = {
      {"whitelist", "allowlist"},
      {"blacklist", "denylist"},
      {"master", "main"},
      {"slave", "replica"},
      {"dummy", "placeholder"},
      {"sanity check", "confidence check"},
      {nullptr, nullptr}
    };

    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py|sh|md)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;
        for (int i = 0; terms[i].term; i++) {
          if (ln.find(terms[i].term) != std::string::npos) {
            findings.push_back({name, "info", file, line, "non-inclusive-term",
                std::string("'") + terms[i].term + "' → use '" + terms[i].replacement + "'", ""});
          }
        }
        pos = eol + 1;
      }
    }
    return findings;
  }
};
