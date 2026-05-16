/**
 * @file dead_docs.cpp
 * @brief Native dead docs check — finds markdown files referencing deleted code.
 */
#include "check.h"

#include <regex>

struct DeadDocsCheck : Check {
  DeadDocsCheck() { name = "dead-docs"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto docs = fs.find_files("docs", "\\.md$");
    for (auto& doc : docs) {
      std::string content = fs.read(doc);
      /* Find code references like `src/foo.cpp` or `src/bar.ts` */
      std::regex ref_pattern("src/[a-zA-Z0-9_/.-]+\\.(cpp|ts|js|py|h)");
      std::sregex_iterator it(content.begin(), content.end(), ref_pattern);
      std::sregex_iterator end;
      for (; it != end; ++it) {
        std::string ref = it->str();
        if (!fs.exists(ref))
          findings.push_back({name, "warning", doc, 0, "dead-reference",
              "References '" + ref + "' which doesn't exist", "Update or remove reference"});
      }
    }
    return findings;
  }
};
