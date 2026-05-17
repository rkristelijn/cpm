/**
 * @file comments.cpp
 * @brief Native comment ratio check — enforces minimum documentation.
 */
#include "check.h"

struct CommentRatioCheck : Check {
  int min_percent = 20;

  CommentRatioCheck() {
    name = "comment-ratio";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(cpp|c|h|hpp)$");
    int total_code = 0, total_comments = 0;

    for (auto& f : files) {
      std::string content = fs.read(f);
      bool in_block = false;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string line = content.substr(pos, eol - pos);
        pos = eol + 1;

        /* Skip empty lines */
        size_t first = line.find_first_not_of(" \t");
        if (first == std::string::npos) continue;

        if (in_block) {
          total_comments++;
          if (line.find("*/") != std::string::npos) in_block = false;
        } else if (line.find("/*") != std::string::npos) {
          total_comments++;
          if (line.find("*/") == std::string::npos) in_block = true;
        } else if (line.substr(first, 2) == "//") {
          total_comments++;
        } else {
          total_code++;
        }
      }
    }

    if (total_code + total_comments == 0) return findings;
    int pct = total_comments * 100 / (total_code + total_comments);
    if (pct < min_percent) {
      findings.push_back({name, "warning", "src/", 0, "low-comment-ratio",
                          std::to_string(pct) + "% comments (min " + std::to_string(min_percent) + "%)",
                          "Add /** @brief */ doxygen comments to functions"});
    }
    return findings;
  }
};
