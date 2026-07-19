/**
// @see ADR-129
 * @file regex_quality.cpp
 * @brief Native regex quality check — detects shell quoting bugs, dialect
 *        mismatches, and ReDoS patterns in source code and scripts.
 *
 * Phase 1 covers:
 * - shell-quoting-mismatch: single quote inside single-quoted regex
 * - pcre-in-ere-context: \d, \w, \s used in grep -E (ERE doesn't support)
 * - bre-ere-mismatch: unescaped +/|/? in BRE grep, or \+ in ERE
 * - redos-nested-quantifiers: (a+)+, (.*)+, nested repetitions
 */
#include "../check.h"

struct RegexQualityCheck : Check {
  RegexQualityCheck() {
    name = "regex-quality";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    /* Scan shell scripts in common locations */
    static const char* shell_dirs[] = {"scripts", "checks", "src", "lib", nullptr};
    for (int i = 0; shell_dirs[i]; i++) {
      auto sh_files = fs.find_files(shell_dirs[i], "\\.(sh|bash)$");
      for (auto& f : sh_files) check_shell_file(fs, f, findings);
    }

    if (fs.exists("Makefile")) check_shell_file(fs, "Makefile", findings);

    /* Scan source for ReDoS patterns */
    auto src_files = fs.find_files("src", "\\.(cpp|h|ts|js|jsx|tsx|py|java)$");
    for (auto& f : src_files) {
      if (f.find("node_modules") != std::string::npos) continue;
      if (f.find("vendor") != std::string::npos) continue;
      check_source_file(fs, f, findings);
    }

    return findings;
  }

 private:
  /** @brief Check a shell script or Makefile for regex issues. */
  void check_shell_file(FileSystem& fs, const std::string& file, std::vector<Finding>& findings) {
    std::string content = fs.read(file);
    if (content.find("cpm:ignore regex") != std::string::npos) return;

    int line = 0;
    size_t pos = 0;
    while (pos < content.size()) {
      size_t eol = content.find('\n', pos);
      if (eol == std::string::npos) eol = content.size();
      std::string ln = content.substr(pos, eol - pos);
      line++;

      /* Skip comments */
      size_t first_non_space = ln.find_first_not_of(" \t");
      if (first_non_space != std::string::npos && ln[first_non_space] == '#') {
        pos = eol + 1;
        continue;
      }

      if (ln.find("grep") != std::string::npos || ln.find("sed") != std::string::npos) {
        check_shell_quoting(ln, file, line, findings);
        check_dialect_mismatch(ln, file, line, findings);
      }

      pos = eol + 1;
    }
  }

  /** @brief Detect single quotes inside single-quoted regex strings. */
  void check_shell_quoting(const std::string& ln, const std::string& file, int line, std::vector<Finding>& findings) {
    /* Find single-quoted strings and check for embedded single quotes.
     * Pattern: content between ' ... ' that contains suspicious fragments
     * suggesting a broken quote boundary. */
    bool in_single = false;
    int sq_start = -1;

    for (size_t i = 0; i < ln.size(); i++) {
      if (ln[i] == '\'' && (i == 0 || ln[i - 1] != '\\')) {
        if (!in_single) {
          in_single = true;
          sq_start = (int)i;
        } else {
          /* End of single-quoted string — check if it's suspiciously short
           * followed immediately by another quote (sign of broken quoting) */
          in_single = false;
          size_t len = i - sq_start - 1;

          /* Pattern: '...[" followed by a bare char then ]...' — classic break */
          if (len == 0 && i + 1 < ln.size() && (ln[i + 1] == '\\' || ln[i + 1] == '*' || ln[i + 1] == '[')) {
            findings.push_back({name, "error", file, line, "shell-quoting-mismatch",
                                "Single-quoted string appears broken — embedded quote splits the regex",
                                "Use double quotes or $'...' quoting for regex containing single quotes"});
            return;
          }
        }
      }
    }

    /* Detect unmatched single quote (odd number) */
    int sq_count = 0;
    for (char c : ln)
      if (c == '\'') sq_count++;
    if (sq_count % 2 != 0 && ln.find("grep") != std::string::npos) {
      findings.push_back({name, "error", file, line, "shell-quoting-mismatch",
                          "Unmatched single quote in grep command — shell will error or match wrong",
                          "Ensure all single-quoted strings are properly closed"});
    }
  }

  /** @brief Detect PCRE features in ERE context or vice versa. */
  void check_dialect_mismatch(const std::string& ln, const std::string& file, int line, std::vector<Finding>& findings) {
    bool is_ere = ln.find("grep -E") != std::string::npos || ln.find("grep -iE") != std::string::npos ||
                  ln.find("grep -rE") != std::string::npos || ln.find("grep -rnE") != std::string::npos ||
                  ln.find("egrep") != std::string::npos || ln.find("grep -r") != std::string::npos && ln.find("-E") != std::string::npos;
    bool is_pcre = ln.find("grep -P") != std::string::npos || ln.find("grep -oP") != std::string::npos;
    bool is_bre = ln.find("grep") != std::string::npos && !is_ere && !is_pcre;

    /* PCRE shorthand in ERE context */
    if (is_ere) {
      /* Look for \d, \w, \s that aren't inside [] and aren't \\d (literal backslash+d) */
      if (has_pcre_shorthand(ln)) {
        findings.push_back({name, "warning", file, line, "pcre-in-ere-context",
                            "\\d/\\w/\\s used in grep -E — ERE doesn't support PCRE shorthands",
                            "Use [0-9], [[:alnum:]_], [[:space:]] or switch to grep -P"});
      }
    }

    /* grep -P portability warning */
    if (is_pcre) {
      findings.push_back({name, "warning", file, line, "grep-p-not-portable", "grep -P is not available on macOS/BSD — breaks portability",
                          "Use grep -E with POSIX classes, or require GNU grep"});
    }

    /* BRE: unescaped + or | or ? (they're literal in BRE) */
    if (is_bre && !is_ere && !is_pcre) {
      if (has_bare_ere_metachar(ln)) {
        findings.push_back({name, "warning", file, line, "bre-ere-mismatch",
                            "Unescaped +/|/? in grep BRE — these are literal characters, not metacharacters",
                            "Use grep -E for extended regex, or escape with \\+, \\|, \\?"});
      }
    }

    /* sed -r is GNU-only */
    if (ln.find("sed -r") != std::string::npos || ln.find("sed -ri") != std::string::npos) {
      findings.push_back({name, "warning", file, line, "sed-r-not-portable", "sed -r is GNU-only — not available on macOS/BSD",
                          "Use sed -E (POSIX/BSD compatible)"});
    }
  }

  /** @brief Check source files for ReDoS-vulnerable patterns. */
  void check_source_file(FileSystem& fs, const std::string& file, std::vector<Finding>& findings) {
    std::string content = fs.read(file);
    if (content.find("cpm:ignore regex") != std::string::npos) return;

    int line = 0;
    size_t pos = 0;
    while (pos < content.size()) {
      size_t eol = content.find('\n', pos);
      if (eol == std::string::npos) eol = content.size();
      std::string ln = content.substr(pos, eol - pos);
      line++;

      /* Only check lines that contain regex patterns */
      if (has_regex_context(ln)) {
        check_redos(ln, file, line, findings);
      }

      pos = eol + 1;
    }
  }

  /** @brief Detect nested quantifiers that cause catastrophic backtracking. */
  void check_redos(const std::string& ln, const std::string& file, int line, std::vector<Finding>& findings) {
    /* Pattern: (X+)+, (X*)+, (X+)*, (X*)* — nested quantifiers */
    for (size_t i = 0; i + 4 < ln.size(); i++) {
      if (ln[i] == ')' && (ln[i + 1] == '+' || ln[i + 1] == '*' || ln[i + 1] == '{')) {
        /* Walk backwards to find matching ( */
        int depth = 1;
        size_t j = i - 1;
        while (j > 0 && depth > 0) {
          if (ln[j] == ')') depth++;
          if (ln[j] == '(') depth--;
          j--;
        }
        /* Check if the group body contains a quantifier */
        std::string body = ln.substr(j + 2, i - j - 2);
        if (body.find('+') != std::string::npos || body.find('*') != std::string::npos) {
          /* Exclude possessive quantifiers (++) and atomic groups */
          if (i + 2 < ln.size() && ln[i + 1] == '+' && ln[i + 2] == '+') continue;
          findings.push_back({name, "error", file, line, "redos-nested-quantifiers",
                              "Nested quantifiers detected — potential catastrophic backtracking (ReDoS)",
                              "Use atomic groups, possessive quantifiers, or restructure the pattern"});
          return; /* One finding per line is enough */
        }
      }
    }
  }

  /* --- Helper functions --- */

  /** @brief Check if line contains PCRE shorthands (\d, \w, \s) in regex position. */
  static bool has_pcre_shorthand(const std::string& ln) {
    for (size_t i = 0; i + 1 < ln.size(); i++) {
      if (ln[i] == '\\' &&
          (ln[i + 1] == 'd' || ln[i + 1] == 'w' || ln[i + 1] == 's' || ln[i + 1] == 'D' || ln[i + 1] == 'W' || ln[i + 1] == 'S')) {
        /* Skip if preceded by another backslash (\\d = literal \d) */
        if (i > 0 && ln[i - 1] == '\\') continue;
        return true;
      }
    }
    return false;
  }

  /** @brief Check if BRE line has bare +, |, ? suggesting user meant ERE. */
  static bool has_bare_ere_metachar(const std::string& ln) {
    /* Extract the pattern portion (after grep flags, inside quotes) */
    size_t pat_start = 0;
    /* Find first quote after grep */
    size_t grep_pos = ln.find("grep");
    if (grep_pos == std::string::npos) return false;
    size_t q = ln.find_first_of("'\"", grep_pos);
    if (q == std::string::npos) return false;
    char qchar = ln[q];
    size_t q_end = ln.find(qchar, q + 1);
    if (q_end == std::string::npos) return false;

    std::string pat = ln.substr(q + 1, q_end - q - 1);

    /* In BRE, bare + | ? are literals. If they appear without preceding \,
     * the user likely intended ERE behavior. */
    for (size_t i = 0; i < pat.size(); i++) {
      if ((pat[i] == '+' || pat[i] == '|' || pat[i] == '?') && (i == 0 || pat[i - 1] != '\\')) {
        /* Ignore + inside character classes [a-z+] */
        bool in_bracket = false;
        for (size_t k = 0; k < i; k++) {
          if (pat[k] == '[') in_bracket = true;
          if (pat[k] == ']' && k > 0) in_bracket = false;
        }
        if (!in_bracket) return true;
      }
    }
    return false;
  }

  /** @brief Check if line likely contains a regex definition. */
  static bool has_regex_context(const std::string& ln) {
    return ln.find("regex") != std::string::npos || ln.find("Regex") != std::string::npos || ln.find("RegExp") != std::string::npos ||
           ln.find("re.compile") != std::string::npos || ln.find("Pattern.compile") != std::string::npos ||
           ln.find("=~ ") != std::string::npos;
  }
};
