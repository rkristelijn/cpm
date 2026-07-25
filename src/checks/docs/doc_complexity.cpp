/**
// @see ADR-137
 * @file doc_complexity.cpp
 * @brief Documentation complexity check — measures readability, structure, completeness.
 *
 * Scores each markdown file on 7 metrics:
 * 1. File length (too long = unreadable)
 * 2. Heading depth (>4 levels = over-structured)
 * 3. Average section length (>50 lines = wall of text)
 * 4. Code block ratio (<10% in tutorials = too abstract)
 * 5. Diagram count (0 in architecture docs = missing visuals)
 * 6. Flesch reading ease (approximation, <30 = academic jargon)
 * 7. List indent depth (>3 levels = too nested)
 *
 * All metrics are file-based, no external tools needed.
 */
#include <cmath>
#include <sstream>

#include "../check.h"

struct DocComplexityCheck : Check {
  DocComplexityCheck() {
    name = "doc-complexity";
    category = "docs";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files(".", "\\.md$");

    /* Doc ratio: total doc lines vs total code lines */
    int total_doc_lines = 0;
    for (auto& file : files) {
      if (file.find("node_modules") != std::string::npos) continue;
      if (file.find("vendor/") != std::string::npos) continue;
      std::string content = fs.read(file);
      int lines = 1;
      for (char c : content)
        if (c == '\n') lines++;
      total_doc_lines += lines;
    }

    /* Count code lines */
    int total_code_lines = 0;
    auto code_exts = {"\\.cpp$", "\\.c$",  "\\.h$",  "\\.hpp$",  "\\.ts$",  "\\.js$",
                      "\\.py$",  "\\.rs$", "\\.go$", "\\.java$", "\\.php$", "\\.rb$"};
    for (auto& ext : code_exts) {
      auto code_files = fs.find_files(".", ext);
      for (auto& cf : code_files) {
        if (cf.find("node_modules") != std::string::npos) continue;
        if (cf.find("vendor/") != std::string::npos) continue;
        std::string content = fs.read(cf);
        int lines = 1;
        for (char c : content)
          if (c == '\n') lines++;
        total_code_lines += lines;
      }
    }

    /* Report ratio if code exists */
    if (total_code_lines > 100) {
      int ratio_pct = total_doc_lines * 100 / total_code_lines;
      if (ratio_pct < 10) {
        findings.push_back({name, "warning", ".", 0, "low-doc-ratio",
                            "Doc ratio: " + std::to_string(ratio_pct) + "% (" + std::to_string(total_doc_lines) + " doc lines / " +
                                std::to_string(total_code_lines) + " code lines) — min 10%",
                            "Add documentation (README, guides, ADRs)"});
      }
    }

    for (auto& file : files) {
      /* Skip vendor, node_modules, build artifacts */
      if (file.find("node_modules") != std::string::npos) continue;
      if (file.find("vendor/") != std::string::npos) continue;

      std::string content = fs.read(file);
      if (content.empty()) continue;

      /* Parse into lines */
      std::vector<std::string> lines;
      std::istringstream stream(content);
      std::string line;
      while (std::getline(stream, line)) lines.push_back(line);

      int total_lines = (int)lines.size();

      /* 1. File length — >500 lines is too long for a single doc */
      if (total_lines > 500) {
        findings.push_back({name, "warning", file, 0, "doc-too-long",
                            "Document is " + std::to_string(total_lines) + " lines (max 500) — consider splitting",
                            "Split into focused sub-documents"});
      }

      /* Collect metrics in one pass */
      int max_heading_depth = 0;
      int heading_count = 0;
      int code_block_lines = 0;
      bool in_code_block = false;
      int diagram_count = 0;
      int max_indent_depth = 0;
      int total_words = 0;
      int total_sentences = 0;
      int total_syllables = 0;

      for (int i = 0; i < total_lines; i++) {
        const std::string& ln = lines[i];

        /* Code blocks */
        if (ln.find("```") == 0 || ln.find("~~~") == 0) {
          in_code_block = !in_code_block;
          /* Detect diagram types */
          if (in_code_block && (ln.find("mermaid") != std::string::npos || ln.find("plantuml") != std::string::npos ||
                                ln.find("dot") != std::string::npos)) {
            diagram_count++;
          }
          continue;
        }
        if (in_code_block) {
          code_block_lines++;
          continue;
        }

        /* Diagrams: also count image references to .drawio, .png, .svg */
        if (ln.find(".drawio") != std::string::npos || ln.find(".svg") != std::string::npos ||
            (ln.find("![") != std::string::npos && ln.find(".png") != std::string::npos)) {
          diagram_count++;
        }

        /* 2. Heading depth */
        if (!ln.empty() && ln[0] == '#') {
          heading_count++;
          int depth = 0;
          while (depth < (int)ln.size() && ln[depth] == '#') depth++;
          if (depth > max_heading_depth) max_heading_depth = depth;
        }

        /* 7. List indent depth */
        if (ln.find("- ") != std::string::npos || ln.find("* ") != std::string::npos) {
          int spaces = 0;
          for (char c : ln) {
            if (c == ' ')
              spaces++;
            else
              break;
          }
          int indent = spaces / 2;
          if (indent > max_indent_depth) max_indent_depth = indent;
        }

        /* Flesch: count words, sentences, syllables (approximation) */
        for (size_t j = 0; j < ln.size(); j++) {
          if (ln[j] == '.' || ln[j] == '!' || ln[j] == '?') total_sentences++;
        }
        /* Count words */
        bool in_word = false;
        std::string word;
        for (char c : ln) {
          if (isalpha(c)) {
            in_word = true;
            word += c;
          } else {
            if (in_word) {
              total_words++;
              total_syllables += count_syllables(word);
              word.clear();
            }
            in_word = false;
          }
        }
        if (in_word) {
          total_words++;
          total_syllables += count_syllables(word);
        }
      }

      /* 2. Heading depth >4 */
      if (max_heading_depth > 4) {
        findings.push_back({name, "info", file, 0, "heading-too-deep",
                            "Heading depth " + std::to_string(max_heading_depth) + " (max 4) — simplify structure",
                            "Flatten heading hierarchy or split document"});
      }

      /* 3. Average section length */
      if (heading_count > 0) {
        int avg_section = total_lines / heading_count;
        if (avg_section > 50) {
          findings.push_back({name, "info", file, 0, "long-sections",
                              "Average section is " + std::to_string(avg_section) + " lines (max 50) — add more headings",
                              "Break long sections with sub-headings"});
        }
      }

      /* 4. Code block ratio — only for docs >20 lines */
      if (total_lines > 20) {
        int pct = code_block_lines * 100 / total_lines;
        /* Tutorials/howtos should have code examples */
        bool is_tutorial = file.find("tutorial") != std::string::npos || file.find("howto") != std::string::npos ||
                           file.find("guide") != std::string::npos || file.find("CONTRIBUTING") != std::string::npos;
        if (is_tutorial && pct < 10) {
          findings.push_back({name, "info", file, 0, "low-code-ratio",
                              "Code block ratio is " + std::to_string(pct) + "% (min 10% for tutorials)",
                              "Add code examples to illustrate concepts"});
        }
      }

      /* 5. Diagram count — architecture docs should have visuals */
      {
        bool is_arch = file.find("architecture") != std::string::npos || file.find("design") != std::string::npos ||
                       file.find("adr") != std::string::npos;
        if (is_arch && total_lines > 50 && diagram_count == 0) {
          findings.push_back({name, "info", file, 0, "no-diagrams", "Architecture doc has no diagrams — add mermaid or image",
                              "Add a diagram to visualize the design"});
        }
      }

      /* 6. Flesch reading ease (approximation)
       * Formula: 206.835 - 1.015*(words/sentences) - 84.6*(syllables/words)
       * <30 = very difficult, 30-50 = difficult, 50-60 = fairly difficult */
      if (total_words > 100 && total_sentences > 0) {
        double flesch = 206.835 - 1.015 * ((double)total_words / total_sentences) - 84.6 * ((double)total_syllables / total_words);
        if (flesch < 30) {
          char buf[64];
          snprintf(buf, sizeof(buf), "%.0f", flesch);
          findings.push_back({name, "info", file, 0, "low-readability",
                              std::string("Flesch score ") + buf + " (min 30) — text is very difficult to read",
                              "Use shorter sentences and simpler words"});
        }
      }

      /* 7. List indent depth >3 */
      if (max_indent_depth > 3) {
        findings.push_back({name, "info", file, 0, "deep-nesting",
                            "List nesting depth " + std::to_string(max_indent_depth) + " (max 3) — flatten structure",
                            "Reduce nesting or use sub-headings instead"});
      }
    }
    return findings;
  }

 private:
  /* Approximate syllable count for English words */
  static int count_syllables(const std::string& word) {
    if (word.size() <= 3) return 1;
    int count = 0;
    bool prev_vowel = false;
    for (size_t i = 0; i < word.size(); i++) {
      char c = tolower(word[i]);
      bool is_vowel = (c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u' || c == 'y');
      if (is_vowel && !prev_vowel) count++;
      prev_vowel = is_vowel;
    }
    /* Silent e */
    if (word.size() > 2 && tolower(word.back()) == 'e') count--;
    return count < 1 ? 1 : count;
  }
};
