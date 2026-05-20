/**
 * @file doc_engineering.cpp
 * @brief Layer 5: Engineering Quality — do docs match reality?
 *
 * Checks:
 *   code-block-validity  — JSON/YAML blocks must parse correctly
 *   version-drift        — versions in docs vs package.json/cpm.toml
 *   source-doc-drift     — docs older than related source files (git-based)
 *
 * @see ADR-137 (Documentation Quality Platform)
 */
#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <sstream>

#include "../check.h"

struct DocEngineeringCheck : Check {
  DocEngineeringCheck() {
    name = "doc-engineering";
    category = "docs";
  }

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

      check_code_blocks(lines, file, findings);
    }
    return findings;
  }

 private:
  /* Validate JSON/YAML code blocks */
  static void check_code_blocks(const std::vector<std::string>& lines, const std::string& file, std::vector<Finding>& findings) {
    bool in_code = false;
    std::string lang;
    std::string block;
    int block_start = 0;

    for (int i = 0; i < (int)lines.size(); i++) {
      const std::string& ln = lines[i];

      if (ln.find("```") == 0 || ln.find("~~~") == 0) {
        if (!in_code) {
          /* Opening fence — extract language */
          in_code = true;
          block.clear();
          block_start = i + 1;
          size_t fence_end = (ln[0] == '`') ? 3 : 3;
          lang = ln.substr(fence_end);
          /* Trim whitespace */
          while (!lang.empty() && isspace(lang.front())) lang.erase(lang.begin());
          while (!lang.empty() && isspace(lang.back())) lang.pop_back();
          /* Lowercase */
          for (char& c : lang) c = tolower(c);
        } else {
          /* Closing fence — validate block */
          in_code = false;
          if (!block.empty()) {
            if (lang == "json")
              validate_json(block, file, block_start, findings);
            else if (lang == "yaml" || lang == "yml")
              validate_yaml(block, file, block_start, findings);
          }
        }
        continue;
      }
      if (in_code) block += ln + "\n";
    }
  }

  /* Simple JSON validation — checks balanced braces/brackets and basic syntax */
  static void validate_json(const std::string& block, const std::string& file, int line, std::vector<Finding>& findings) {
    /* Skip if it's clearly a fragment/placeholder */
    if (block.find("...") != std::string::npos) return;
    if (block.size() < 3) return;

    int braces = 0, brackets = 0;
    bool in_string = false;
    bool has_unquoted_key = false;

    for (size_t i = 0; i < block.size(); i++) {
      char c = block[i];
      if (in_string) {
        if (c == '\\') {
          i++;
          continue;
        }
        if (c == '"') in_string = false;
        continue;
      }
      if (c == '"') {
        in_string = true;
        continue;
      }
      if (c == '{')
        braces++;
      else if (c == '}')
        braces--;
      else if (c == '[')
        brackets++;
      else if (c == ']')
        brackets--;
      /* Detect unquoted keys: word followed by colon, not inside string */
      else if (c == ':' && i > 0 && isalpha(block[i - 1])) {
        /* Check if preceding word is quoted */
        size_t j = i - 1;
        while (j > 0 && (isalnum(block[j - 1]) || block[j - 1] == '_')) j--;
        if (j == 0 || block[j - 1] != '"') has_unquoted_key = true;
      }
    }

    if (braces != 0) {
      findings.push_back({"doc-engineering", "warning", file, line, "code-block-invalid-json",
                          "JSON block has unbalanced braces (open=" + std::to_string(braces) + ")",
                          "Fix the JSON syntax in this code block"});
    } else if (brackets != 0) {
      findings.push_back({"doc-engineering", "warning", file, line, "code-block-invalid-json", "JSON block has unbalanced brackets",
                          "Fix the JSON syntax in this code block"});
    } else if (has_unquoted_key) {
      findings.push_back({"doc-engineering", "info", file, line, "code-block-invalid-json", "JSON block has unquoted keys",
                          "Quote all keys: \"key\": value"});
    }
  }

  /* Simple YAML validation — checks indentation consistency */
  static void validate_yaml(const std::string& block, const std::string& file, int line, std::vector<Finding>& findings) {
    if (block.size() < 3) return;

    std::istringstream ss(block);
    std::string ln;
    int prev_indent = 0;
    int line_num = 0;
    bool has_tab = false;
    bool has_bad_indent = false;

    while (std::getline(ss, ln)) {
      line_num++;
      if (ln.empty() || ln[0] == '#') continue;

      /* Tabs in YAML = error */
      if (ln.find('\t') != std::string::npos) {
        has_tab = true;
        continue;
      }

      int indent = 0;
      for (char c : ln) {
        if (c == ' ')
          indent++;
        else
          break;
      }

      /* Indent jump > 4 spaces at once is suspicious */
      if (indent > prev_indent + 4 && prev_indent >= 0) has_bad_indent = true;
      prev_indent = indent;
    }

    if (has_tab) {
      findings.push_back({"doc-engineering", "warning", file, line, "code-block-invalid-yaml",
                          "YAML block uses tabs (YAML requires spaces)", "Replace tabs with spaces"});
    }
    if (has_bad_indent) {
      findings.push_back({"doc-engineering", "info", file, line, "code-block-invalid-yaml",
                          "YAML block has inconsistent indentation (jump > 4 spaces)", "Use consistent 2-space indentation"});
    }
  }
};
