/**
 * @file doc_type_detect.cpp
 * @brief Layer 3: Document type detection via deterministic weighted signals.
 *
 * Detects 19 document archetypes using filename, path, and structural heuristics.
 * No AI — purely weighted signal scoring. Highest score wins.
 *
 * Once type is detected, validates type-specific quality contracts.
 *
 * @see ADR-137 (Documentation Quality Platform)
 */
#include <algorithm>
#include <cctype>
#include <cstring>
#include <sstream>

#include "../check.h"

struct DocTypeDetectCheck : Check {
  DocTypeDetectCheck() {
    name = "doc-type";
    category = "docs";
  }

  enum Type {
    T_README,
    T_ONBOARDING,
    T_TUTORIAL,
    T_HOWTO,
    T_REFERENCE,
    T_EXPLANATION,
    T_ARCHITECTURE,
    T_ADR,
    T_TROUBLESHOOTING,
    T_RUNBOOK,
    T_CONTRIBUTING,
    T_SECURITY,
    T_RELEASE_NOTES,
    T_MIGRATION,
    T_API,
    T_CLI,
    T_FAQ,
    T_GLOSSARY,
    T_STYLE_GUIDE,
    T_UNKNOWN,
    T_COUNT
  };

  static const char* type_name(Type t) {
    static const char* names[] = {"readme",       "onboarding",   "tutorial",      "how-to",          "reference",
                                  "explanation",  "architecture", "adr",           "troubleshooting", "runbook",
                                  "contributing", "security",     "release-notes", "migration",       "api",
                                  "cli",          "faq",          "glossary",      "style-guide",     "unknown"};
    return names[t];
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files(".", "\\.md$");

    for (auto& file : files) {
      if (file.find("node_modules") != std::string::npos) continue;
      if (file.find("vendor/") != std::string::npos) continue;

      std::string content = fs.read(file);
      if (content.empty()) continue;

      /* Parse basic structure */
      std::vector<std::string> lines;
      std::istringstream stream(content);
      std::string line;
      while (std::getline(stream, line)) lines.push_back(line);
      if (lines.size() < 5) continue;

      std::string lower_file = to_lower(file);
      std::string basename = get_basename(lower_file);
      std::string lower_content = to_lower(content);

      /* Score each type */
      int scores[T_COUNT] = {};

      /* --- 1. Filename heuristics (high confidence) --- */
      if (basename == "readme.md" || basename == "readme") scores[T_README] += 100;
      if (basename == "contributing.md") scores[T_CONTRIBUTING] += 100;
      if (basename == "security.md") scores[T_SECURITY] += 100;
      if (basename == "changelog.md" || basename == "changes.md") scores[T_RELEASE_NOTES] += 100;
      if (basename == "faq.md") scores[T_FAQ] += 100;
      if (basename == "glossary.md") scores[T_GLOSSARY] += 100;
      if (basename == "style-guide.md" || basename == "styleguide.md") scores[T_STYLE_GUIDE] += 100;
      if (basename == "migration.md" || basename.find("upgrade") != std::string::npos) scores[T_MIGRATION] += 80;
      if (basename == "onboarding.md" || basename == "getting-started.md") scores[T_ONBOARDING] += 80;
      if (basename == "troubleshooting.md") scores[T_TROUBLESHOOTING] += 80;

      /* --- 2. Path heuristics --- */
      if (lower_file.find("/adr") != std::string::npos || lower_file.find("/adrs/") != std::string::npos) scores[T_ADR] += 60;
      if (lower_file.find("/runbook") != std::string::npos) scores[T_RUNBOOK] += 60;
      if (lower_file.find("/tutorial") != std::string::npos) scores[T_TUTORIAL] += 60;
      if (lower_file.find("/how-to") != std::string::npos || lower_file.find("/howto") != std::string::npos) scores[T_HOWTO] += 60;
      if (lower_file.find("/api/") != std::string::npos) scores[T_API] += 60;
      if (lower_file.find("/architecture") != std::string::npos) scores[T_ARCHITECTURE] += 60;
      if (lower_file.find("/reference") != std::string::npos) scores[T_REFERENCE] += 50;
      if (lower_file.find("/migration") != std::string::npos) scores[T_MIGRATION] += 50;

      /* --- 3. Structural heuristics --- */
      int table_lines = 0, code_blocks = 0, numbered_lists = 0;
      int h2_count = 0, short_sections = 0;
      bool in_code = false;
      std::vector<std::string> headings;

      for (auto& ln : lines) {
        if (ln.find("```") == 0) {
          in_code = !in_code;
          if (in_code) code_blocks++;
          continue;
        }
        if (in_code) continue;
        if (!ln.empty() && ln[0] == '|') table_lines++;
        if (!ln.empty() && ln[0] == '#') headings.push_back(to_lower(ln));
        if (ln.find("## ") == 0) h2_count++;
        if (ln.size() > 1 && ln[0] >= '1' && ln[0] <= '9' && ln[1] == '.') numbered_lists++;
      }

      /* Count short sections (avg < 10 lines per heading) */
      if (h2_count > 3 && (int)lines.size() / h2_count < 10) short_sections = 1;

      /* Heading content analysis */
      std::string all_headings;
      for (auto& h : headings) all_headings += h + " ";

      /* README signals */
      if (has_heading(headings, "install")) scores[T_README] += 20;
      if (has_heading(headings, "quick start")) scores[T_README] += 20;
      if (lower_content.find("![") != std::string::npos && lower_content.find("badge") != std::string::npos) scores[T_README] += 15;
      if (lower_file.find("./readme") != std::string::npos || file == "./README.md") scores[T_README] += 30;

      /* Tutorial signals */
      if (has_heading_pattern(headings, "step ")) scores[T_TUTORIAL] += 50;
      if (numbered_lists > 3) scores[T_TUTORIAL] += 30;
      if (code_blocks > 3) scores[T_TUTORIAL] += 20;
      if (count_words(lower_content, "create|run|install|build|open") > 5) scores[T_TUTORIAL] += 10;

      /* Reference signals */
      if (table_lines > 10) scores[T_REFERENCE] += 30;
      if (has_heading(headings, "parameter") || has_heading(headings, "option")) scores[T_REFERENCE] += 30;
      if (short_sections) scores[T_REFERENCE] += 20;
      if (has_heading(headings, "flag") || has_heading(headings, "command")) scores[T_CLI] += 30;

      /* ADR signals */
      if (headings.size() > 0 && headings[0].find("adr") != std::string::npos) scores[T_ADR] += 100;
      if (has_heading(headings, "decision")) scores[T_ADR] += 20;
      if (has_heading(headings, "context")) scores[T_ADR] += 15;
      if (has_heading(headings, "consequence")) scores[T_ADR] += 15;

      /* Architecture signals */
      if (has_heading(headings, "architecture")) scores[T_ARCHITECTURE] += 40;
      if (count_words(lower_content, "service|component|flow|layer|module") > 3) scores[T_ARCHITECTURE] += 20;
      if (lower_content.find("```mermaid") != std::string::npos) scores[T_ARCHITECTURE] += 20;

      /* Troubleshooting signals */
      if (has_heading(headings, "symptom") || has_heading(headings, "cause") || has_heading(headings, "solution"))
        scores[T_TROUBLESHOOTING] += 40;
      if (count_words(lower_content, "if you see|error|fix|resolve|workaround") > 3) scores[T_TROUBLESHOOTING] += 20;

      /* Runbook signals */
      if (count_words(lower_content, "incident|recovery|alert|monitor|escalat") > 2) scores[T_RUNBOOK] += 30;
      if (has_heading(headings, "escalation") || has_heading(headings, "contact")) scores[T_RUNBOOK] += 20;

      /* How-to signals */
      if (headings.size() > 0 && headings[0].find("how to") != std::string::npos) scores[T_HOWTO] += 50;
      if (code_blocks > 1 && code_blocks < 5 && (int)lines.size() < 80) scores[T_HOWTO] += 15;

      /* API signals */
      if (has_heading(headings, "endpoint") || has_heading(headings, "request") || has_heading(headings, "response")) scores[T_API] += 30;
      if (count_words(lower_content, "get |post |put |delete |patch ") > 2) scores[T_API] += 20;

      /* FAQ signals */
      int question_headings = 0;
      for (auto& h : headings)
        if (h.find("?") != std::string::npos) question_headings++;
      if (question_headings > 2) scores[T_FAQ] += 40;

      /* Migration signals */
      if (count_words(lower_content, "breaking change|deprecat|upgrade|migrat") > 2) scores[T_MIGRATION] += 30;
      if (has_heading(headings, "before") && has_heading(headings, "after")) scores[T_MIGRATION] += 30;

      /* Find winner */
      Type detected = T_UNKNOWN;
      int max_score = 30; /* minimum threshold to classify */
      for (int t = 0; t < T_COUNT; t++) {
        if (scores[t] > max_score) {
          max_score = scores[t];
          detected = (Type)t;
        }
      }

      /* Validate type-specific contracts */
      if (detected != T_UNKNOWN) validate_contract(detected, lines, headings, code_blocks, table_lines, file, findings);
    }
    return findings;
  }

 private:
  static std::string to_lower(const std::string& s) {
    std::string r = s;
    std::transform(r.begin(), r.end(), r.begin(), ::tolower);
    return r;
  }

  static std::string get_basename(const std::string& path) {
    size_t pos = path.rfind('/');
    return pos != std::string::npos ? path.substr(pos + 1) : path;
  }

  static bool has_heading(const std::vector<std::string>& headings, const char* keyword) {
    for (auto& h : headings)
      if (h.find(keyword) != std::string::npos) return true;
    return false;
  }

  static bool has_heading_pattern(const std::vector<std::string>& headings, const char* prefix) {
    for (auto& h : headings) {
      size_t start = h.find_first_not_of("# ");
      if (start != std::string::npos && h.find(prefix, start) == start) return true;
    }
    return false;
  }

  static int count_words(const std::string& text, const char* words_pipe) {
    int count = 0;
    std::string w;
    std::istringstream ss(words_pipe);
    while (std::getline(ss, w, '|')) {
      size_t pos = 0;
      while ((pos = text.find(w, pos)) != std::string::npos) {
        count++;
        pos += w.size();
      }
    }
    return count;
  }

  static void validate_contract(Type type, const std::vector<std::string>& lines, const std::vector<std::string>& headings, int code_blocks,
                                int table_lines, const std::string& file, std::vector<Finding>& findings) {
    switch (type) {
      case T_TUTORIAL:
        if (code_blocks < 2)
          findings.push_back({"doc-type", "warning", file, 0, "tutorial-no-examples",
                              "Tutorial has " + std::to_string(code_blocks) + " code blocks (min 2)", "Add code examples for each step"});
        if (!has_heading(headings, "prerequisite") && !has_heading(headings, "requirement"))
          findings.push_back({"doc-type", "info", file, 0, "tutorial-no-prerequisites", "Tutorial missing prerequisites section",
                              "Add a Prerequisites section listing what readers need"});
        break;
      case T_ADR:
        if (!has_heading(headings, "decision"))
          findings.push_back({"doc-type", "warning", file, 0, "adr-no-decision", "ADR missing 'Decision' section",
                              "Add a ## Decision section stating what was decided"});
        if (!has_heading(headings, "context"))
          findings.push_back({"doc-type", "info", file, 0, "adr-no-context", "ADR missing 'Context' section",
                              "Add a ## Context section explaining the problem"});
        break;
      case T_REFERENCE:
        if (table_lines < 3 && code_blocks < 2)
          findings.push_back({"doc-type", "info", file, 0, "reference-no-structure", "Reference doc has no tables or code examples",
                              "Add tables for parameters/options or code examples"});
        break;
      case T_README:
        if (!has_heading(headings, "install") && !has_heading(headings, "setup") && !has_heading(headings, "getting started") &&
            !has_heading(headings, "quick start"))
          findings.push_back(
              {"doc-type", "info", file, 0, "readme-no-install", "README missing install/setup section", "Add installation instructions"});
        break;
      case T_TROUBLESHOOTING:
        if (!has_heading(headings, "symptom") && !has_heading(headings, "problem") && !has_heading(headings, "error") &&
            !has_heading(headings, "issue"))
          findings.push_back({"doc-type", "info", file, 0, "troubleshooting-no-symptoms",
                              "Troubleshooting doc missing symptom/problem descriptions", "Structure as: Symptom → Cause → Solution"});
        break;
      case T_API:
        if (!has_heading(headings, "error") && !has_heading(headings, "status"))
          findings.push_back(
              {"doc-type", "info", file, 0, "api-no-errors", "API doc missing error codes section", "Document possible error responses"});
        break;
      default:
        break;
    }
    (void)lines;
  }
};
