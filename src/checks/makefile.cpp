/**
 * @file makefile.cpp
 * @brief Native Makefile check — verifies best practices.
 */
#include "check.h"

struct MakefileCheck : Check {
  MakefileCheck() {
    name = "makefile";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    if (!fs.exists("Makefile")) return findings;
    std::string content = fs.read("Makefile");

    /* Check line count — Makefiles should be thin dispatch, not logic */
    int lines = 1;
    for (char c : content)
      if (c == '\n') lines++;
    if (lines > 60)
      findings.push_back({name, "warning", "Makefile", 0, "too-long", "Makefile has " + std::to_string(lines) + " lines (max 60)",
                          "Move logic to scripts/ and keep Makefile as thin dispatch"});

    /* Check for .PHONY declaration */
    if (content.find(".PHONY") == std::string::npos)
      findings.push_back({name, "warning", "Makefile", 0, "no-phony", "No .PHONY declaration", "Add .PHONY for non-file targets"});

    /* Check for help target */
    if (content.find("help:") == std::string::npos && content.find("help :") == std::string::npos)
      findings.push_back({name, "info", "Makefile", 0, "no-help-target", "No help target", "Add self-documenting help with ## comments"});

    return findings;
  }
};
