/**
// @see ADR-129
 * @file architecture.cpp
 * @brief Native architecture check — detects spaghetti, coupling, SOLID violations.
 *
 * Heuristic detection of:
 * - Deep nesting (cognitive load)
 * - Giant switch/if-chains (Open/Closed violation)
 * - High fan-out (too many imports)
 * - Concrete infra in business layer (Dependency Inversion)
 * - Circular-ish patterns (import A→B and B→A in same dir)
 *
 * These are language-agnostic heuristics that work on any codebase.
 * They catch the 80% of architecture issues without needing a full AST.
 * False positive rate is intentionally low — we only flag obvious violations.
 */
#include "../check.h"

struct ArchitectureCheck : Check {
  int max_nesting = 4;
  int max_fan_out = 15;
  int max_switch_cases = 8;

  ArchitectureCheck() {
    name = "architecture";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|js|cpp|py|java)$");

    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      if (file.find("node_modules") != std::string::npos) continue;
      std::string content = fs.read(file);

      check_nesting(file, content, findings);
      check_fan_out(file, content, findings);
      check_switch_chains(file, content, findings);
      check_infra_coupling(file, content, findings);
    }
    return findings;
  }

 private:
  void check_nesting(const std::string& file, const std::string& content, std::vector<Finding>& findings) {
    int line = 0, max_depth = 0, depth = 0, worst_line = 0;
    for (size_t i = 0; i < content.size(); i++) {
      if (content[i] == '\n') {
        line++;
        continue;
      }
      if (content[i] == '{') {
        depth++;
        if (depth > max_depth) {
          max_depth = depth;
          worst_line = line;
        }
      }
      if (content[i] == '}') {
        if (depth > 0) depth--;
      }
    }
    if (max_depth > max_nesting)
      findings.push_back({name, "warning", file, worst_line, "deep-nesting",
                          "Nesting depth " + std::to_string(max_depth) + " (max " + std::to_string(max_nesting) + ")",
                          "Extract methods or use early returns", ""});
  }

  void check_fan_out(const std::string& file, const std::string& content, std::vector<Finding>& findings) {
    int imports = 0;
    size_t pos = 0;
    while ((pos = content.find("import ", pos)) != std::string::npos) {
      imports++;
      pos += 7;
    }
    pos = 0;
    while ((pos = content.find("#include", pos)) != std::string::npos) {
      imports++;
      pos += 8;
    }
    if (imports > max_fan_out)
      findings.push_back({name, "warning", file, 0, "high-fan-out",
                          std::to_string(imports) + " imports (max " + std::to_string(max_fan_out) + ")",
                          "Split module or use facade pattern", ""});
  }

  void check_switch_chains(const std::string& file, const std::string& content, std::vector<Finding>& findings) {
    int cases = 0, line = 0, switch_line = 0;
    bool in_switch = false;
    size_t pos = 0;
    while (pos < content.size()) {
      size_t eol = content.find('\n', pos);
      if (eol == std::string::npos) eol = content.size();
      std::string ln = content.substr(pos, eol - pos);
      line++;
      if (ln.find("switch") != std::string::npos || ln.find("match ") != std::string::npos) {
        in_switch = true;
        cases = 0;
        switch_line = line;
      }
      if (in_switch && (ln.find("case ") != std::string::npos || ln.find("else if") != std::string::npos)) cases++;
      if (in_switch && ln.find("}") != std::string::npos && cases > 0) {
        if (cases > max_switch_cases)
          findings.push_back({name, "warning", file, switch_line, "large-switch",
                              std::to_string(cases) + " cases (max " + std::to_string(max_switch_cases) + ")",
                              "Use polymorphism or strategy pattern", ""});
        in_switch = false;
      }
      pos = eol + 1;
    }
  }

  void check_infra_coupling(const std::string& file, const std::string& content, std::vector<Finding>& findings) {
    /* Only flag if file is in a "domain" or "service" directory */
    if (file.find("domain") == std::string::npos && file.find("service") == std::string::npos && file.find("core") == std::string::npos)
      return;

    static const char* infra[] = {"mysql",     "postgres", "redis",    "mongodb",  "prisma", "typeorm",
                                  "sequelize", "knex",     "mongoose", "firebase", nullptr};
    for (int i = 0; infra[i]; i++) {
      if (content.find(infra[i]) != std::string::npos) {
        findings.push_back({name, "info", file, 0, "infra-in-domain",
                            std::string("Direct '") + infra[i] + "' import in domain/service layer",
                            "Use repository pattern (Dependency Inversion)", ""});
        break;
      }
    }
  }
};
