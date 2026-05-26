/**
 * @file unsafe_str.cpp
 * @brief Detects unsafe C string functions (strcpy, strcat, sprintf, gets).
 *
 * Shift-left check: catches buffer overflow risks before they reach SonarCloud.
 * Suggests bounded alternatives (snprintf, memcpy, fgets).
 */
#include "../check.h"

struct UnsafeStrCheck : Check {
  UnsafeStrCheck() {
    name = "unsafe-str";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(c|cpp|cc|h|hpp)$");
    for (auto& file : files) {
      if (file.find("_test.") != std::string::npos) continue;
      if (file.find("vendor/") != std::string::npos) continue;
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;
        /* Skip comments */
        if (ln.find("//") < ln.find("strcpy") && ln.find("//") < ln.find("strcat") &&
            ln.find("//") < ln.find("sprintf") && ln.find("//") < ln.find("gets("))
          goto next;
        if (ln.find("strcpy(") != std::string::npos)
          findings.push_back({name, "warning", file, line, "strcpy",
                              "strcpy() has no bounds checking — buffer overflow risk",
                              "Use snprintf(dst, sizeof(dst), \"%s\", src)"});
        else if (ln.find("strcat(") != std::string::npos)
          findings.push_back({name, "warning", file, line, "strcat",
                              "strcat() has no bounds checking — buffer overflow risk",
                              "Use snprintf() with position tracking or strlcat()"});
        else if (ln.find("sprintf(") != std::string::npos)
          findings.push_back({name, "warning", file, line, "sprintf",
                              "sprintf() has no bounds checking — buffer overflow risk",
                              "Use snprintf(buf, sizeof(buf), ...)"});
        else if (ln.find("gets(") != std::string::npos)
          findings.push_back({name, "error", file, line, "gets",
                              "gets() is always unsafe — removed in C11",
                              "Use fgets(buf, sizeof(buf), stdin)"});
      next:
        pos = eol + 1;
      }
    }
    return findings;
  }
};
