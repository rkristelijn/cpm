/**
// @see ADR-139
 * @file inclusivity.cpp
 * @brief Native inclusivity check — flags non-inclusive terminology.
 */
#include <regex>

#include "../check.h"

struct InclusivityCheck : Check {
  InclusivityCheck() {
    name = "inclusivity";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    /* Non-inclusive terms with severity and category */
    static const struct {
      const char* term;
      const char* replacement;
      const char* severity;  // error, warning, info
      const char* category;  // for rationale
    } terms[] = {            // error: historically loaded / racial
                 {"whitelist", "allowlist", "error", "racial"},
                 {"blacklist", "denylist", "error", "racial"},
                 {"master/slave", "primary/secondary", "error", "slavery"},
                 {"slave", "replica", "error", "slavery"},

                 // warning: ableist / mental health
                 {"sanity check", "confidence check", "warning", "ableist"},
                 {"crazy", "unexpected", "warning", "ableist"},
                 {"insane", "extreme", "warning", "ableist"},
                 {"cripple", "severely limit", "warning", "ableist"},
                 {"crippled", "degraded", "warning", "ableist"},
                 {"lame", "weak", "warning", "ableist"},
                 {"dumb", "simple", "warning", "ableist"},
                 {"blind spot", "visibility gap", "warning", "ableist"},

                 // warning: gendered
                 {"man-hours", "person-hours", "warning", "gendered"},
                 {"manpower", "workforce", "warning", "gendered"},
                 {"middleman", "intermediary", "warning", "gendered"},
                 {"guys", "everyone", "warning", "gendered"},

                 // warning: violent framing
                 {"war room", "incident room", "warning", "violent"},
                 {"kill switch", "emergency stop", "warning", "violent"},
                 {"bus factor", "lottery factor", "warning", "violent"},

                 // warning: exclusionary
                 {"grandfathered", "legacy exempt", "warning", "exclusionary"},
                 {"tribal knowledge", "institutional knowledge", "warning", "exclusionary"},
                 {"native speaker", "fluent speaker", "warning", "exclusionary"},
                 {"normal user", "typical user", "warning", "exclusionary"},

                 // info: toxic culture / shaming in docs
                 {"RTFM", "see documentation", "info", "culture"},
                 {"obviously", "clearly", "info", "culture"},
                 {"simply", "straightforwardly", "info", "culture"},
                 {"trivial", "small", "info", "culture"},
                 {"stupid", "incorrect", "info", "culture"},

                 // info: placeholder (context-dependent)
                 {"dummy", "placeholder", "info", "ableist"},

                 {nullptr, nullptr, nullptr, nullptr}};

    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py|sh|md)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;
        for (int i = 0; terms[i].term; i++) {
          if (ln.find(terms[i].term) != std::string::npos) {
            findings.push_back({name, terms[i].severity, file, line, "non-inclusive-term",
                                std::string("'") + terms[i].term + "' -> '" + terms[i].replacement + "' (" + terms[i].category + ")", ""});
          }
        }
        pos = eol + 1;
      }
    }
    return findings;
  }
};
