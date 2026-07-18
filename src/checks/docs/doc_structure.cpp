/**
 * @file doc_structure.cpp
 * @brief Layer 2: Structural quality — scanability, flow, navigation.
 *
 * Checks whether a document is usable, not just well-written.
 * A well-structured doc lets readers find what they need without reading everything.
 *
 * Loads required-sections per doc type from dictionaries/doc-types.txt.
 */
#include <algorithm>
#include <cctype>
#include <map>
#include <set>
#include <sstream>

#include "../check.h"

struct DocStructureCheck : Check {
  DocStructureCheck() {
    name = "doc-structure";
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

      int total_lines = (int)lines.size();
      if (total_lines < 10) continue; /* Skip tiny files */

      /* Collect structure info in one pass */
      std::vector<std::string> headings;
      std::vector<int> heading_lines;
      int code_blocks = 0;
      bool in_code = false;
      bool has_table = false;
      int max_list_run = 0;
      int current_list_run = 0;

      for (int i = 0; i < total_lines; i++) {
        const std::string& ln = lines[i];

        if (ln.rfind("```", 0) == 0 || ln.rfind("~~~", 0) == 0) {
          if (!in_code) code_blocks++;
          in_code = !in_code;
          continue;
        }
        if (in_code) continue;

        if (!ln.empty() && ln[0] == '#') {
          headings.push_back(to_lower(ln));
          heading_lines.push_back(i);
        }
        if (!ln.empty() && ln[0] == '|') has_table = true;

        /* Track list runs */
        bool is_list = false;
        size_t first = ln.find_first_not_of(" ");
        if (first != std::string::npos && (ln[first] == '-' || ln[first] == '*' || (ln[first] >= '0' && ln[first] <= '9'))) is_list = true;

        if (is_list) {
          current_list_run++;
        } else {
          if (current_list_run > max_list_run) max_list_run = current_list_run;
          current_list_run = 0;
        }
      }
      if (current_list_run > max_list_run) max_list_run = current_list_run;

      /* Detect doc type from path/content */
      std::string type = detect_type(file, headings);

      /* === Checks === */

      /* 1. Missing summary — docs >30 lines should have intro before first heading */
      if (total_lines > 30 && heading_lines.size() >= 2) {
        /* Check if there's content between h1 and h2 */
        int h1_line = heading_lines[0];
        int h2_line = heading_lines.size() > 1 ? heading_lines[1] : total_lines;
        int intro_lines = h2_line - h1_line - 1;
        /* Count non-empty lines in intro */
        int intro_content = 0;
        for (int i = h1_line + 1; i < h2_line && i < total_lines; i++)
          if (!lines[i].empty()) intro_content++;
        if (intro_content == 0) {
          findings.push_back({name, "warning", file, h1_line + 1, "missing-summary",
                              "No summary/intro after title — reader doesn't know what this doc is about",
                              "Add 1-2 sentences explaining the purpose of this document"});
        }
      }

      /* 2. No examples in docs >50 lines */
      if (total_lines > 50 && code_blocks == 0 && !has_table) {
        findings.push_back({name, "info", file, 0, "missing-example",
                            "No code examples or tables in " + std::to_string(total_lines) + " lines — too abstract",
                            "Add at least one concrete example"});
      }

      /* 3. Giant list (>20 items without grouping) */
      if (max_list_run > 20) {
        findings.push_back({name, "info", file, 0, "giant-list",
                            "List with " + std::to_string(max_list_run) + " consecutive items (max 20) — group with sub-headings",
                            "Break into logical groups with headings"});
      }

      /* 4. Orphan section (heading followed by <2 lines before next heading of SAME or higher level) */
      for (int h = 0; h < (int)heading_lines.size() - 1; h++) {
        int start = heading_lines[h] + 1;
        int end = heading_lines[h + 1];
        int curr_depth = heading_depth(headings[h]);
        int next_depth = heading_depth(headings[h + 1]);
        /* Skip if next heading is deeper (this is a parent/container heading) */
        if (next_depth > curr_depth) continue;
        int content_lines = 0;
        for (int i = start; i < end; i++)
          if (!lines[i].empty()) content_lines++;
        if (content_lines == 0) {
          findings.push_back({name, "info", file, heading_lines[h] + 1, "orphan-section",
                              "Section '" + strip_hashes(lines[heading_lines[h]]) + "' is empty", "Add content or remove the heading"});
        }
      }

      /* 5. Inconsistent heading levels (skip from h2 to h4) */
      for (int h = 1; h < (int)headings.size(); h++) {
        int prev_depth = heading_depth(headings[h - 1]);
        int curr_depth = heading_depth(headings[h]);
        if (curr_depth > prev_depth + 1) {
          findings.push_back(
              {name, "warning", file, heading_lines[h] + 1, "skipped-heading-level",
               "Heading jumps from h" + std::to_string(prev_depth) + " to h" + std::to_string(curr_depth) + " — skipped a level",
               "Use h" + std::to_string(prev_depth + 1) + " instead, or add intermediate heading"});
        }
      }

      /* 6. Type-specific: ADR missing required sections */
      if (type == "adr" && total_lines > 20) {
        check_required_sections(findings, file, headings, heading_lines, {"context", "decision"}, "ADR");
      }

      /* 7. Type-specific: Tutorial/guide missing prerequisites or steps */
      if (type == "tutorial") {
        check_required_sections(findings, file, headings, heading_lines, {"prerequisite", "install", "step", "usage", "example", "run"},
                                "Tutorial");
      }

      /* 8. No next steps — doc ends without pointing somewhere */
      if (total_lines > 30 && !headings.empty()) {
        std::string last_heading = headings.back();
        bool has_next = last_heading.find("next") != std::string::npos || last_heading.find("see also") != std::string::npos ||
                        last_heading.find("reference") != std::string::npos || last_heading.find("further") != std::string::npos;
        /* Also check last 5 lines for links */
        bool has_links = false;
        for (int i = std::max(0, total_lines - 5); i < total_lines; i++)
          if (lines[i].find("@see") != std::string::npos || lines[i].find("](") != std::string::npos) has_links = true;
        if (!has_next && !has_links && type != "adr") {
          findings.push_back({name, "info", file, total_lines, "no-next-steps", "Document ends without next steps or references — dead end",
                              "Add a 'See also' or 'Next steps' section"});
        }
      }
    }
    return findings;
  }

 private:
  static std::string to_lower(const std::string& s) {
    std::string r = s;
    std::transform(r.begin(), r.end(), r.begin(), ::tolower);
    return r;
  }

  static int heading_depth(const std::string& heading) {
    int d = 0;
    for (char c : heading) {
      if (c == '#')
        d++;
      else
        break;
    }
    return d;
  }

  static std::string strip_hashes(const std::string& heading) {
    size_t start = heading.find_first_not_of("# ");
    return start != std::string::npos ? heading.substr(start) : heading;
  }

  static std::string detect_type(const std::string& file, const std::vector<std::string>& headings) {
    std::string lower_file = file;
    std::transform(lower_file.begin(), lower_file.end(), lower_file.begin(), ::tolower);

    if (lower_file.find("adr") != std::string::npos) return "adr";
    if (lower_file.find("tutorial") != std::string::npos) return "tutorial";
    if (lower_file.find("guide") != std::string::npos) return "tutorial";
    if (lower_file.find("howto") != std::string::npos) return "tutorial";
    if (lower_file.find("contributing") != std::string::npos) return "tutorial";
    if (lower_file.find("troubleshoot") != std::string::npos) return "troubleshooting";

    /* Detect from headings */
    for (auto& h : headings) {
      if (h.find("context") != std::string::npos && h.find("decision") != std::string::npos) return "adr";
    }
    return "general";
  }

  static void check_required_sections(std::vector<Finding>& findings, const std::string& file, const std::vector<std::string>& headings,
                                      const std::vector<int>& heading_lines, const std::vector<std::string>& required,
                                      const std::string& doc_type) {
    (void)heading_lines;
    for (auto& req : required) {
      bool found = false;
      for (auto& h : headings) {
        if (h.find(req) != std::string::npos) {
          found = true;
          break;
        }
      }
      if (!found) {
        findings.push_back({"doc-structure", "info", file, 0, "missing-section", doc_type + " missing '" + req + "' section",
                            "Add a section covering: " + req});
      }
    }
  }
};
