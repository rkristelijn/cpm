/**
// @see ADR-137
 * @file doc_style.cpp
 * @brief Documentation writing style check — consistency, clarity, tone.
 *
 * Loads word/pattern lists from dictionaries/ (cSpell-compatible format).
 * One entry per line, # comments, optional |fix metadata after pipe.
 *
 * Dictionaries loaded:
 *   dictionaries/weasel-words.txt      — words that exclude beginners
 *   dictionaries/passive-patterns.txt  — passive voice in instructions
 *   dictionaries/hedging-phrases.txt   — weak/indecisive language
 *   dictionaries/non-imperative.txt    — "you should" instead of imperative
 *   dictionaries/acronyms-common.txt   — known acronyms (no expansion needed)
 *
 * Users can override by placing files in .config/ or adding to cpm.toml.
 */
#include <algorithm>
#include <cctype>
#include <cstdio>
#include <set>
#include <sstream>

#include "../check.h"

struct DictEntry {
  std::string pattern;
  std::string fix;
};

struct DocStyleCheck : Check {
  DocStyleCheck() {
    name = "doc-style";
    category = "docs";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    /* Load dictionaries */
    auto weasels = load_dict(fs, "dictionaries/weasel-words.txt");
    auto passives = load_dict(fs, "dictionaries/passive-patterns.txt");
    auto hedges = load_dict(fs, "dictionaries/hedging-phrases.txt");
    auto non_imp = load_dict(fs, "dictionaries/non-imperative.txt");
    auto acronyms = load_wordlist(fs, "dictionaries/acronyms-common.txt");

    /* Also load project-specific acronyms if present */
    auto project_acr = load_wordlist(fs, ".config/project-acronyms.txt");
    acronyms.insert(project_acr.begin(), project_acr.end());

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

      bool in_code = false;
      std::set<std::string> addressing_forms;
      std::set<std::string> seen_acronyms;

      for (int i = 0; i < (int)lines.size(); i++) {
        const std::string& ln = lines[i];

        /* Skip code blocks */
        if (ln.find("```") == 0 || ln.find("~~~") == 0) {
          in_code = !in_code;
          continue;
        }
        if (in_code) continue;
        /* Skip headings, tables, frontmatter (but NOT list items) */
        if (!ln.empty() && (ln[0] == '#' || ln[0] == '|')) continue;
        if (ln.find("---") == 0) continue;
        if (!ln.empty() && ln[0] == '[' && ln.find("](") != std::string::npos) continue;

        std::string lower = to_lower(ln);

        /* 1. Weasel words */
        for (auto& w : weasels) {
          if (word_at(lower, w.pattern)) {
            findings.push_back({name, "info", file, i + 1, "weasel-word", "'" + w.pattern + "' — " + w.fix, w.fix});
            break;
          }
        }

        /* 2. Passive voice */
        for (auto& p : passives) {
          if (lower.find(p.pattern) != std::string::npos) {
            findings.push_back({name, "info", file, i + 1, "passive-voice", "Passive: '" + p.pattern + "' — " + p.fix,
                                "Rewrite in active voice: " + p.fix});
            break;
          }
        }

        /* 3. Addressing consistency */
        detect_addressing(lower, addressing_forms);

        /* 4. Non-imperative in list items */
        if (is_list_item(ln)) {
          std::string text = list_item_text(ln);
          std::string lower_text = to_lower(text);
          for (auto& ni : non_imp) {
            if (lower_text.find(ni.pattern) == 0) {
              findings.push_back(
                  {name, "info", file, i + 1, "non-imperative", "'" + ni.pattern + "...' — " + ni.fix, "Remove subject, start with verb"});
              break;
            }
          }
        }

        /* 5. Undefined acronyms */
        check_acronyms(ln, i + 1, file, seen_acronyms, acronyms, findings);

        /* 6. Hedging */
        for (auto& h : hedges) {
          /* Short patterns need word boundary check to avoid false positives */
          bool matched = h.pattern.size() <= 10 ? word_at(lower, h.pattern) : lower.find(h.pattern) != std::string::npos;
          if (matched) {
            findings.push_back({name, "info", file, i + 1, "hedging", "'" + h.pattern + "' — " + h.fix, h.fix});
            break;
          }
        }
      }

      /* Report mixed addressing */
      if (addressing_forms.size() > 1) {
        std::string forms;
        for (auto& f : addressing_forms) forms += f + ", ";
        if (!forms.empty()) forms = forms.substr(0, forms.size() - 2);
        findings.push_back({name, "warning", file, 0, "mixed-addressing", "Mixed addressing: " + forms + " — pick one and be consistent",
                            "Choose one form and use it throughout"});
      }
    }
    return findings;
  }

 private:
  /* Load a dictionary file: lines with optional |fix after pipe */
  static std::vector<DictEntry> load_dict(FileSystem& fs, const std::string& path) {
    std::vector<DictEntry> entries;
    std::string content = fs.read(path);
    if (content.empty()) return entries;
    std::istringstream stream(content);
    std::string line;
    while (std::getline(stream, line)) {
      if (line.empty() || line[0] == '#') continue;
      size_t pipe = line.find('|');
      if (pipe != std::string::npos) {
        entries.push_back({line.substr(0, pipe), line.substr(pipe + 1)});
      } else {
        entries.push_back({line, ""});
      }
    }
    return entries;
  }

  /* Load a plain word list (one word per line, # comments) */
  static std::set<std::string> load_wordlist(FileSystem& fs, const std::string& path) {
    std::set<std::string> words;
    std::string content = fs.read(path);
    if (content.empty()) return words;
    std::istringstream stream(content);
    std::string line;
    while (std::getline(stream, line)) {
      if (line.empty() || line[0] == '#') continue;
      /* Trim whitespace */
      while (!line.empty() && isspace(line.back())) line.pop_back();
      while (!line.empty() && isspace(line.front())) line.erase(line.begin());
      if (!line.empty()) words.insert(line);
    }
    return words;
  }

  static std::string to_lower(const std::string& s) {
    std::string r = s;
    std::transform(r.begin(), r.end(), r.begin(), ::tolower);
    return r;
  }

  static bool word_at(const std::string& lower, const std::string& word) {
    size_t pos = 0;
    while ((pos = lower.find(word, pos)) != std::string::npos) {
      bool start_ok = (pos == 0 || !isalpha(lower[pos - 1]));
      bool end_ok = (pos + word.size() >= lower.size() || !isalpha(lower[pos + word.size()]));
      if (start_ok && end_ok) return true;
      pos++;
    }
    return false;
  }

  static bool is_list_item(const std::string& ln) {
    size_t start = ln.find_first_not_of(" ");
    return start != std::string::npos && (ln[start] == '-' || ln[start] == '*');
  }

  static std::string list_item_text(const std::string& ln) {
    size_t start = ln.find_first_not_of(" ");
    if (start == std::string::npos) return "";
    size_t text = ln.find_first_not_of(" ", start + 1);
    return text != std::string::npos ? ln.substr(text) : "";
  }

  static void detect_addressing(const std::string& lower, std::set<std::string>& forms) {
    if (word_at(lower, "you") || word_at(lower, "your")) forms.insert("you/your");
    if (word_at(lower, "we") || word_at(lower, "our")) forms.insert("we/our");
    if (word_at(lower, "je") || word_at(lower, "jouw")) forms.insert("je/jouw");
  }

  static void check_acronyms(const std::string& raw, int line, const std::string& file, std::set<std::string>& seen,
                             const std::set<std::string>& known, std::vector<Finding>& findings) {
    std::string word;
    for (size_t i = 0; i <= raw.size(); i++) {
      char c = i < raw.size() ? raw[i] : ' ';
      if (isupper(c)) {
        word += c;
      } else {
        if (word.size() >= 3 && word.size() <= 6 && !known.count(word)) {
          /* Skip UPPER_SNAKE_CASE */
          bool in_snake = (i < raw.size() && raw[i] == '_') || (i > word.size() && raw[i - word.size() - 1] == '_');
          /* Skip common English words that appear in CAPS (BDD, headings) */
          static const char* eng[] = {"NOT",   "AND",  "BUT",  "THE",  "FOR",   "ALL",  "ARE",  "WAS",  "HAS",  "HAD",  "CAN",
                                      "MAY",   "RUN",  "SET",  "GET",  "PUT",   "NEW",  "OLD",  "ADD",  "USE",  "FIX",  "END",
                                      "TOP",   "LOW",  "MAX",  "MIN",  "SUM",   "AVG",  "KEY",  "VAL",  "DIR",  "SRC",  "BIN",
                                      "LIB",   "OPT",  "VAR",  "TMP",  "LOG",   "ERR",  "OUT",  "YES",  "WHEN", "THEN", "GIVEN",
                                      "INDEX", "PATH", "FILE", "NAME", "TYPE",  "NODE", "RULE", "TEST", "PASS", "FAIL", "SKIP",
                                      "WARN",  "INFO", "NONE", "TRUE", "FALSE", "NULL", nullptr};
          bool is_eng = false;
          for (int j = 0; eng[j]; j++)
            if (word == eng[j]) {
              is_eng = true;
              break;
            }
          if (!in_snake && !is_eng && !seen.count(word)) {
            findings.push_back({"doc-style", "info", file, line, "undefined-acronym",
                                "'" + word + "' used without expansion — define on first use",
                                "Add: '" + word + " (Full Name)' on first occurrence"});
          }
          seen.insert(word);
        }
        word.clear();
      }
    }
  }
};
