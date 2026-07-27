// @deprecated — migrated to rule engine (.rule file). Remove in v0.8.0.
/**
// @see ADR-129
 * @file async.cpp
 * @brief Native async check — enforce async/await over .then()/.catch().
 */
#include "../check.h"

struct AsyncCheck : Check {
  AsyncCheck() {
    name = "async";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.ts$");
    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;
        if (ln.find(".then(") != std::string::npos)
          findings.push_back({name, "info", file, line, "prefer-await", ".then() — prefer async/await", ""});
        if (ln.find("new Promise(") != std::string::npos)
          findings.push_back({name, "info", file, line, "avoid-new-promise", "new Promise() — usually unnecessary with async/await", ""});
        pos = eol + 1;
      }
    }
    return findings;
  }
};
