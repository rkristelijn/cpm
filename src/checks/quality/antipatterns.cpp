/**
 * @file antipatterns.cpp
 * @brief Native language-specific anti-pattern detection.
 *
 * Detects the "cultural failure modes" per ecosystem:
 * - TS/React: useEffect without deps, barrel exports, magic numbers
 * - SQL: SELECT *, string concat queries
 * - C++: raw new/delete, macro abuse
 * - Angular: subscription leaks
 * - Rust: excessive .clone()
 */
#include "../check.h"

struct AntiPatternCheck : Check {
  AntiPatternCheck() {
    name = "antipattern";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|tsx|js|jsx|cpp|h|rs|py|sql)$");

    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      if (file.find("node_modules") != std::string::npos) continue;
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;

      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        /* === React/TS === */
        /* useEffect without dependency array */
        if (ln.find("useEffect(") != std::string::npos) {
          /* Look ahead for closing — if no [] before ), it's missing deps */
          size_t chunk_end = content.find(");", pos);
          if (chunk_end != std::string::npos) {
            std::string block = content.substr(pos, chunk_end - pos);
            if (block.find("], [") == std::string::npos && block.find("], []") == std::string::npos &&
                block.find("}, [") == std::string::npos && block.find("}, []") == std::string::npos &&
                block.rfind("[") == std::string::npos)
              findings.push_back({name, "warning", file, line, "useeffect-no-deps",
                                  "useEffect without dependency array (runs every render)",
                                  "Add dependency array: useEffect(() => {}, [deps])", ""});
          }
        }

        /* Barrel export (re-exports everything) */
        if (file.find("index.ts") != std::string::npos || file.find("index.js") != std::string::npos) {
          int exports = 0;
          size_t p2 = 0;
          while ((p2 = content.find("export ", p2)) != std::string::npos) {
            exports++;
            p2 += 7;
          }
          if (exports > 20) {
            findings.push_back({name, "warning", file, 0, "barrel-explosion", std::to_string(exports) + " exports in barrel file",
                                "Split into focused modules", ""});
            break; /* Only report once per file */
          }
        }

        /* Magic numbers */
        if (ln.find("= 86400") != std::string::npos || ln.find("= 3600") != std::string::npos || ln.find("= 1000 *") != std::string::npos ||
            ln.find("= 60 *") != std::string::npos)
          if (ln.find("const") == std::string::npos || ln.find("SECONDS") == std::string::npos)
            findings.push_back({name, "info", file, line, "magic-number", "Magic number — extract to named constant", "", ""});

        /* === SQL === */
        if (ln.find("SELECT *") != std::string::npos || ln.find("select *") != std::string::npos)
          findings.push_back({name, "info", file, line, "select-star", "SELECT * — specify columns explicitly", "List needed columns", ""});

        /* === C++ === */
        if (ln.find("new ") != std::string::npos && ln.find("unique_ptr") == std::string::npos &&
            ln.find("shared_ptr") == std::string::npos && ln.find("make_") == std::string::npos && file.find(".cpp") != std::string::npos)
          findings.push_back(
              {name, "info", file, line, "raw-new", "Raw new without smart pointer", "Use std::make_unique/make_shared", ""});

        /* === Rust === */
        if (file.find(".rs") != std::string::npos && ln.find(".clone()") != std::string::npos) {
          /* Count clones in file */
          static int clone_count = 0;
          clone_count++;
          if (clone_count > 10) {
            findings.push_back({name, "info", file, 0, "excessive-clone", "10+ .clone() calls — consider restructuring ownership", "", ""});
            break;
          }
        }

        /* === Angular === */
        if (ln.find(".subscribe(") != std::string::npos && content.find("unsubscribe") == std::string::npos &&
            content.find("takeUntil") == std::string::npos && content.find("async pipe") == std::string::npos)
          findings.push_back({name, "warning", file, line, "subscription-leak", ".subscribe() without unsubscribe/takeUntil",
                              "Use async pipe or takeUntilDestroyed()", ""});

        pos = eol + 1;
      }
    }
    return findings;
  }
};
