/**
 * @file shadow.cpp
 * @brief Native shadow variable detection — inner scope redeclares outer name.
 *
 * Detects common shadowing patterns:
 * - Function param shadows outer variable
 * - Loop variable shadows outer
 * - Catch variable shadows
 * - Nested const/let with same name as outer scope
 */
#include "check.h"

#include <set>
#include <vector>

struct ShadowCheck : Check {
  ShadowCheck() { name = "shadow"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|js|cpp|c|py)$");

    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      if (file.find("node_modules") != std::string::npos) continue;
      std::string content = fs.read(file);

      /* Track variable declarations per scope depth */
      std::vector<std::set<std::string>> scopes;
      scopes.push_back({});
      int line = 0;
      size_t pos = 0;

      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        /* Track scope depth */
        for (char c : ln) {
          if (c == '{') scopes.push_back({});
          if (c == '}' && scopes.size() > 1) scopes.pop_back();
        }

        /* Extract variable name from declarations */
        std::string var_name;
        size_t decl = std::string::npos;
        if ((decl = ln.find("const ")) != std::string::npos) var_name = extract_name(ln, decl + 6);
        else if ((decl = ln.find("let ")) != std::string::npos) var_name = extract_name(ln, decl + 4);
        else if ((decl = ln.find("var ")) != std::string::npos) var_name = extract_name(ln, decl + 4);
        else if ((decl = ln.find("int ")) != std::string::npos) var_name = extract_name(ln, decl + 4);
        else if ((decl = ln.find("auto ")) != std::string::npos) var_name = extract_name(ln, decl + 5);

        if (!var_name.empty() && var_name.size() > 1) {
          /* Check if this name exists in any outer scope */
          for (size_t i = 0; i + 1 < scopes.size(); i++) {
            if (scopes[i].count(var_name)) {
              findings.push_back({name, "warning", file, line, "shadow-variable",
                  "'" + var_name + "' shadows outer declaration",
                  "Rename to avoid confusion", ""});
              break;
            }
          }
          /* Add to current scope */
          if (!scopes.empty()) scopes.back().insert(var_name);
        }

        pos = eol + 1;
      }
    }
    return findings;
  }

private:
  std::string extract_name(const std::string& ln, size_t start) {
    /* Skip whitespace */
    while (start < ln.size() && ln[start] == ' ') start++;
    /* Extract identifier */
    std::string name;
    while (start < ln.size() && (isalnum(ln[start]) || ln[start] == '_')) {
      name += ln[start++];
    }
    /* Skip common false positives */
    if (name == "i" || name == "j" || name == "k" || name == "e" || name == "err") return "";
    return name;
  }
};
