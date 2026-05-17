/**
 * @file dead_code.cpp
 * @brief Native dead code detection — finds orphan modules nobody imports.
 *
 * Scans all source files, builds "who imports whom" graph,
 * flags files that are never imported by anything (orphans).
 * Excludes entry points (main, index, test files).
 */
#include <set>

#include "check.h"

struct DeadCodeCheck : Check {
  DeadCodeCheck() {
    name = "dead-code";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|js|cpp|py)$");

    /* Collect all import targets */
    std::set<std::string> imported;
    for (auto& file : files) {
      if (file.find("node_modules") != std::string::npos) continue;
      std::string content = fs.read(file);
      /* Extract what this file imports */
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        /* Find relative import paths */
        size_t q = ln.find("from '");
        if (q == std::string::npos) q = ln.find("from \"");
        if (q == std::string::npos) q = ln.find("#include \"");
        if (q != std::string::npos) {
          size_t q1 = ln.find_first_of("'\"", q + 5);
          size_t q2 = ln.find_first_of("'\"", q1 + 1);
          if (q1 != std::string::npos && q2 != std::string::npos) {
            std::string path = ln.substr(q1 + 1, q2 - q1 - 1);
            /* Extract filename stem */
            size_t slash = path.rfind('/');
            std::string stem = slash != std::string::npos ? path.substr(slash + 1) : path;
            /* Remove extension */
            size_t dot = stem.rfind('.');
            if (dot != std::string::npos) stem = stem.substr(0, dot);
            imported.insert(stem);
          }
        }
        pos = eol + 1;
      }
    }

    /* Find orphans: files nobody imports */
    for (auto& file : files) {
      if (file.find("node_modules") != std::string::npos) continue;
      if (file.find("test") != std::string::npos) continue;
      /* Skip entry points */
      if (file.find("main") != std::string::npos) continue;
      if (file.find("index") != std::string::npos) continue;
      if (file.find("app") != std::string::npos) continue;

      /* Get stem of this file */
      size_t slash = file.rfind('/');
      std::string stem = slash != std::string::npos ? file.substr(slash + 1) : file;
      size_t dot = stem.rfind('.');
      if (dot != std::string::npos) stem = stem.substr(0, dot);

      if (!imported.count(stem))
        findings.push_back({name, "info", file, 0, "orphan-module", "Module '" + stem + "' is never imported",
                            "Remove if unused, or add to entry point", ""});
    }
    return findings;
  }
};
