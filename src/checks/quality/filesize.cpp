/**
 * @file filesize.cpp
 * @brief Native file size check — enforces max lines per file.
 */
#include "../check.h"

struct FileSizeCheck : Check {
  int max_source = 600;
  int max_header = 300;
  int max_script = 300;

  FileSizeCheck() {
    name = "file-size";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(cpp|c|ts|js|py|go|java|php)$");
    for (auto& f : files) {
      int lines = count_lines(fs.read(f));
      if (lines > max_source)
        findings.push_back({name, "warning", f, 0, "file-too-large",
                            std::to_string(lines) + " lines (max " + std::to_string(max_source) + ")", "Split into smaller modules"});
    }
    auto headers = fs.find_files("src", "\\.(h|hpp)$");
    for (auto& f : headers) {
      int lines = count_lines(fs.read(f));
      if (lines > max_header)
        findings.push_back({name, "warning", f, 0, "header-too-large",
                            std::to_string(lines) + " lines (max " + std::to_string(max_header) + ")", "Split interface"});
    }
    return findings;
  }

 private:
  static int count_lines(const std::string& s) {
    int n = 0;
    for (char c : s)
      if (c == '\n') n++;
    return n;
  }
};
