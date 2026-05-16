/**
 * @file slop.cpp
 * @brief Native slop detection — flags AI-generated anti-patterns.
 */
#include "check.h"

struct SlopCheck : Check {
  SlopCheck() { name = "slop"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    static const struct { const char* pattern; const char* msg; } slops[] = {
      {"Certainly!", "AI filler phrase in comment/string"},
      {"I'd be happy to", "AI filler phrase"},
      {"As an AI", "AI self-reference"},
      {"It's important to note", "AI filler phrase"},
      {"Let me know if", "AI filler phrase in code"},
      {"straightforward", "AI overused word"},
      {"I cannot and will not", "AI refusal in code"},
      {nullptr, nullptr}
    };

    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py|md)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;
        for (int i = 0; slops[i].pattern; i++) {
          if (ln.find(slops[i].pattern) != std::string::npos) {
            findings.push_back({name, "info", file, line, "ai-slop", slops[i].msg, "Remove or rewrite"});
          }
        }
        pos = eol + 1;
      }
    }
    return findings;
  }
};
