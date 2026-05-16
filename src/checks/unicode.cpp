/**
 * @file unicode.cpp
 * @brief Native unicode check — detects invisible/confusable characters.
 */
#include "check.h"

struct UnicodeCheck : Check {
  UnicodeCheck() { name = "unicode"; category = "security"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        /* Check for non-ASCII in code (not comments/strings) */
        for (size_t i = pos; i < eol; i++) {
          unsigned char c = content[i];
          /* Zero-width characters (U+200B-U+200F, U+FEFF) */
          if (c == 0xE2 && i + 2 < eol) {
            unsigned char c2 = content[i+1], c3 = content[i+2];
            if (c2 == 0x80 && (c3 >= 0x8B && c3 <= 0x8F)) {
              findings.push_back({name, "error", file, line + 1, "zero-width-char",
                  "Zero-width character detected (potential trojan source)", "Remove invisible character"});
            }
          }
          /* BOM in middle of file */
          if (c == 0xEF && i > 0 && i + 2 < eol) {
            unsigned char c2 = content[i+1], c3 = content[i+2];
            if (c2 == 0xBB && c3 == 0xBF)
              findings.push_back({name, "warning", file, line + 1, "unexpected-bom",
                  "BOM found in middle of file", "Remove BOM"});
          }
        }
        line++;
        pos = eol + 1;
      }
    }
    return findings;
  }
};
