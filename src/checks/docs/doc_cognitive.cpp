/**
 * @file doc_cognitive.cpp
 * @brief Layer 4: Cognitive Load — measures mental effort required to read docs.
 *
 * Based on Cognitive Load Theory (Sweller 1988) and Miller's Law (7±2 chunks).
 * Detects extraneous cognitive load — load caused by bad presentation, not the topic.
 *
 * Checks:
 *   concept-density       — too many new terms per section (max 5)
 *   stacked-instructions  — too many actions per paragraph (max 3)
 *   forward-references    — "see below" overload (max 2 per section)
 *   paragraph-wall        — >8 consecutive prose lines without break
 *   memory-overload       — tables >20 rows or lists >15 items ungrouped
 *   high-scroll-distance  — key sections (install, usage, api) below 60%
 *
 * @see ADR-137 (Documentation Quality Platform)
 * @see https://github.com/zakirullin/cognitive-load
 */
#include <algorithm>
#include <cctype>
#include <cstring>
#include <set>
#include <sstream>

#include "../check.h"

struct DocCognitiveCheck : Check {
  DocCognitiveCheck() {
    name = "doc-cognitive";
    category = "docs";
  }

  struct Section {
    int start = 0;
    int end = 0;
    std::string heading;
  };

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files(".", "\\.md$");

    for (auto& file : files) {
      if (file.find("node_modules") != std::string::npos) continue;
      if (file.find("vendor/") != std::string::npos) continue;
      if (file.find("CHANGELOG") != std::string::npos) continue;

      std::string content = fs.read(file);
      if (content.empty()) continue;

      std::vector<std::string> lines;
      std::istringstream stream(content);
      std::string line;
      while (std::getline(stream, line)) lines.push_back(line);

      int total_lines = (int)lines.size();
      if (total_lines < 10) continue;

      /* Parse into sections (split by headings) */
      std::vector<Section> sections;
      for (int i = 0; i < total_lines; i++) {
        if (!lines[i].empty() && lines[i][0] == '#') {
          if (!sections.empty()) sections.back().end = i;
          sections.push_back({i, total_lines, lines[i]});
        }
      }
      if (sections.empty()) continue;

      std::set<std::string> all_terms_seen;
      bool in_code = false;

      for (auto& sec : sections) {
        std::set<std::string> section_terms;
        int imperative_count = 0;
        int forward_ref_count = 0;
        int consecutive_prose = 0;
        int max_prose_run = 0;
        int prose_run_start = 0;
        int table_rows = 0;
        int list_items = 0;

        for (int i = sec.start + 1; i < sec.end; i++) {
          const std::string& ln = lines[i];

          /* Track code blocks */
          if (ln.rfind("```", 0) == 0 || ln.rfind("~~~", 0) == 0) {
            in_code = !in_code;
            consecutive_prose = 0;
            continue;
          }
          if (in_code) continue;

          /* --- Paragraph wall detection --- */
          bool is_prose = !ln.empty() && ln[0] != '#' && ln[0] != '|' && ln[0] != '-' && ln[0] != '*' && ln[0] != '>' &&
                          !(ln[0] >= '0' && ln[0] <= '9' && ln.find(". ") < 4);
          if (is_prose) {
            if (consecutive_prose == 0) prose_run_start = i;
            consecutive_prose++;
          } else {
            if (consecutive_prose > max_prose_run) max_prose_run = consecutive_prose;
            consecutive_prose = 0;
          }

          /* --- Table row counting --- */
          if (!ln.empty() && ln[0] == '|')
            table_rows++;
          else if (table_rows > 20) {
            findings.push_back({name, "info", file, i, "memory-overload",
                                "Table with " + std::to_string(table_rows) + " rows — group with sub-headings (max 20 ungrouped)",
                                "Split into logical groups with headings between them"});
            table_rows = 0;
          } else {
            table_rows = 0;
          }

          /* --- List item counting --- */
          size_t first = ln.find_first_not_of(" ");
          bool is_list = first != std::string::npos && (ln[first] == '-' || ln[first] == '*');
          if (is_list)
            list_items++;
          else if (list_items > 15) {
            findings.push_back({name, "info", file, i, "memory-overload",
                                "List with " + std::to_string(list_items) + " items — group with sub-headings (max 15 ungrouped)",
                                "Break into logical groups"});
            list_items = 0;
          } else {
            list_items = 0;
          }

          std::string lower = to_lower(ln);

          /* --- Forward references --- */
          if (lower.find("see below") != std::string::npos || lower.find("explained later") != std::string::npos ||
              lower.find("described in the") != std::string::npos || lower.find("we'll cover") != std::string::npos ||
              lower.find("more on this") != std::string::npos || lower.find("as we'll see") != std::string::npos) {
            forward_ref_count++;
          }

          /* --- Stacked instructions --- */
          imperative_count += count_imperatives(ln);

          /* --- Concept density: extract technical terms --- */
          extract_terms(ln, section_terms);
        }
        /* End of section — check paragraph wall */
        if (consecutive_prose > max_prose_run) max_prose_run = consecutive_prose;

        /* Report paragraph wall */
        if (max_prose_run > 8) {
          findings.push_back({name, "warning", file, prose_run_start + 1, "paragraph-wall",
                              std::to_string(max_prose_run) + " consecutive lines of prose without break (max 8)",
                              "Add a blank line, heading, list, or code block to break it up"});
        }

        /* Report forward references */
        if (forward_ref_count > 2) {
          findings.push_back(
              {name, "info", file, sec.start + 1, "forward-references",
               std::to_string(forward_ref_count) + " forward references in section (max 2) — reader must hold these in memory",
               "Reorder content so referenced material comes first"});
        }

        /* Report stacked instructions */
        if (imperative_count > 5) {
          findings.push_back({name, "warning", file, sec.start + 1, "stacked-instructions",
                              std::to_string(imperative_count) + " imperative actions in section without visual breaks",
                              "Use numbered steps or break into sub-sections"});
        }

        /* Report concept density */
        std::set<std::string> new_terms;
        for (auto& t : section_terms) {
          if (!all_terms_seen.count(t)) new_terms.insert(t);
        }
        if ((int)new_terms.size() > 5) {
          findings.push_back({name, "warning", file, sec.start + 1, "concept-density",
                              std::to_string(new_terms.size()) + " new terms introduced in this section (max 5)",
                              "Split section or introduce terms gradually"});
        }
        all_terms_seen.insert(section_terms.begin(), section_terms.end());
      }

      /* --- High scroll distance: key sections buried (only for long docs) --- */
      if (total_lines > 50) check_scroll_distance(lines, sections, total_lines, file, findings);
    }
    return findings;
  }

 private:
  static std::string to_lower(const std::string& s) {
    std::string r = s;
    std::transform(r.begin(), r.end(), r.begin(), ::tolower);
    return r;
  }

  /* Count imperative verbs in a line */
  static int count_imperatives(const std::string& ln) {
    static const char* verbs[] = {"run",     "install", "create",  "add",      "set",    "open",   "click",  "navigate", "configure",
                                  "build",   "start",   "stop",    "copy",     "paste",  "move",   "delete", "update",   "enable",
                                  "disable", "restart", "execute", "download", "upload", "deploy", nullptr};
    std::string lower = ln;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
    int count = 0;
    for (int v = 0; verbs[v]; v++) {
      size_t pos = 0;
      size_t vlen = strlen(verbs[v]);
      while ((pos = lower.find(verbs[v], pos)) != std::string::npos) {
        bool start_ok = (pos == 0 || !isalpha(lower[pos - 1]));
        bool end_ok = (pos + vlen >= lower.size() || !isalpha(lower[pos + vlen]));
        if (start_ok && end_ok) count++;
        pos += vlen;
      }
    }
    return count;
  }

  /* Extract technical terms from a line (backticks, UPPER_CASE, compounds) */
  static void extract_terms(const std::string& ln, std::set<std::string>& terms) {
    /* Backtick-enclosed terms */
    size_t pos = 0;
    while ((pos = ln.find('`', pos)) != std::string::npos) {
      size_t end = ln.find('`', pos + 1);
      if (end == std::string::npos) break;
      std::string term = ln.substr(pos + 1, end - pos - 1);
      if (term.size() >= 2 && term.size() <= 40) terms.insert(term);
      pos = end + 1;
    }
    /* UPPER_CASE words (3+ chars, not common English) */
    std::string word;
    for (size_t i = 0; i <= ln.size(); i++) {
      char c = i < ln.size() ? ln[i] : ' ';
      if (isupper(c) || c == '_') {
        word += c;
      } else {
        if (word.size() >= 3 && word.find('_') != std::string::npos) {
          terms.insert(word);
        }
        word.clear();
      }
    }
  }

  /* Check if key sections are buried too deep */
  static void check_scroll_distance(const std::vector<std::string>& /*lines*/, const std::vector<Section>& sections, int total_lines,
                                    const std::string& file, std::vector<Finding>& findings) {
    static const char* key_words[] = {"install",         "setup",       "usage", "example",  "quickstart",
                                      "getting started", "quick start", "api",   "customiz", nullptr};

    for (auto& sec : sections) {
      std::string lower_heading = sec.heading;
      std::transform(lower_heading.begin(), lower_heading.end(), lower_heading.begin(), ::tolower);
      for (int k = 0; key_words[k]; k++) {
        if (lower_heading.find(key_words[k]) != std::string::npos) {
          int pct = sec.start * 100 / total_lines;
          if (pct > 60) {
            findings.push_back({"doc-cognitive", "info", file, sec.start + 1, "high-scroll-distance",
                                "'" + sec.heading.substr(sec.heading.find_first_not_of("# ")) + "' is at " + std::to_string(pct) +
                                    "% of document — most readers need this earlier",
                                "Move this section higher or split the document"});
          }
          break;
        }
      }
    }
  }
};
