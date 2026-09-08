/**
// @see ADR-171
 * @file cmd_docs.cpp
 * @brief Documentation tooling. `cpm docs index` generates a deterministic
 *        Markdown index of a documentation directory.
 *
 * Iteration 1 (ADR-171): deterministic only, no LLM.
 *   - Walk *.md in a directory (non-recursive).
 *   - Extract title (frontmatter `title:` or first H1) + one-line summary
 *     (first non-empty, non-heading paragraph, truncated).
 *   - Write a Markdown table between <!-- cpm:docs-index --> markers into
 *     README.md if present, else a fully-owned INDEX.md.
 *   - `--check` regenerates and diffs against the on-disk index; non-zero on drift.
 *
 * Never writes to the repository root.
 */
#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#include <algorithm>
#include <string>
#include <vector>

#include "commands.h"

namespace {

constexpr size_t kSummaryMax = 120;
const char* kMarkerStart = "<!-- cpm:docs-index:start -->";
const char* kMarkerEnd = "<!-- cpm:docs-index:end -->";

struct DocEntry {
  std::string filename;  // basename, e.g. "best-practice.md"
  std::string title;     // extracted title
  std::string summary;   // one-line summary
};

bool is_dir(const std::string& path) {
  struct stat st;
  return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

bool is_file(const std::string& path) {
  struct stat st;
  return stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

std::string read_file(const std::string& path) {
  FILE* f = fopen(path.c_str(), "r");
  if (!f) return "";
  std::string content;
  char buf[4096];
  size_t n;
  while ((n = fread(buf, 1, sizeof(buf), f)) > 0) content.append(buf, n);
  fclose(f);
  return content;
}

std::string trim(const std::string& s) {
  size_t a = s.find_first_not_of(" \t\r\n");
  if (a == std::string::npos) return "";
  size_t b = s.find_last_not_of(" \t\r\n");
  return s.substr(a, b - a + 1);
}

// Escape a cell value for a Markdown table (pipes and stray newlines).
std::string md_cell(const std::string& s) {
  std::string out;
  for (char c : s) {
    if (c == '|')
      out += "\\|";
    else if (c == '\n' || c == '\r')
      out += ' ';
    else
      out += c;
  }
  return out;
}

std::string truncate_summary(const std::string& s) {
  std::string t = trim(s);
  if (t.size() <= kSummaryMax) return t;
  // Truncate on a word boundary where possible.
  std::string cut = t.substr(0, kSummaryMax);
  size_t sp = cut.find_last_of(' ');
  if (sp != std::string::npos && sp > kSummaryMax / 2) cut = cut.substr(0, sp);
  return cut + "…";
}

// Split content into lines (keeps it simple; strips trailing \r).
std::vector<std::string> split_lines(const std::string& content) {
  std::vector<std::string> lines;
  std::string cur;
  for (char c : content) {
    if (c == '\n') {
      if (!cur.empty() && cur.back() == '\r') cur.pop_back();
      lines.push_back(cur);
      cur.clear();
    } else {
      cur += c;
    }
  }
  if (!cur.empty()) {
    if (cur.back() == '\r') cur.pop_back();
    lines.push_back(cur);
  }
  return lines;
}

// Extract title + summary from a Markdown document.
// Title: YAML frontmatter `title:` if present, else first `# H1`, else filename.
// Summary: first non-empty line that is not a heading, frontmatter, or marker.
void extract(const std::string& content, const std::string& fallback_title, std::string& title, std::string& summary) {
  title.clear();
  summary.clear();
  auto lines = split_lines(content);

  bool in_frontmatter = false;
  bool frontmatter_done = false;
  for (size_t i = 0; i < lines.size(); i++) {
    std::string line = lines[i];
    std::string t = trim(line);

    // Frontmatter handling: a leading '---' opens it.
    if (i == 0 && t == "---") {
      in_frontmatter = true;
      continue;
    }
    if (in_frontmatter) {
      if (t == "---") {
        in_frontmatter = false;
        frontmatter_done = true;
        continue;
      }
      // title: from frontmatter (highest priority)
      if (title.empty() && t.rfind("title:", 0) == 0) {
        std::string v = trim(t.substr(6));
        // Strip surrounding quotes.
        if (v.size() >= 2 && (v.front() == '"' || v.front() == '\'') && v.back() == v.front()) v = v.substr(1, v.size() - 2);
        title = v;
      }
      continue;
    }

    if (t.empty()) continue;

    // First H1 as title (if no frontmatter title).
    if (title.empty() && t.rfind("# ", 0) == 0) {
      title = trim(t.substr(2));
      continue;
    }

    // Summary: first content line that is not a heading or marker.
    if (summary.empty()) {
      if (t[0] == '#') continue;              // any heading
      if (t.rfind("<!--", 0) == 0) continue;  // comment/marker
      if (t == "---") continue;               // hr
      if (t[0] == '|') continue;              // table row
      summary = t;
    }

    if (!title.empty() && !summary.empty()) break;
  }

  (void)frontmatter_done;
  if (title.empty()) title = fallback_title;
  summary = truncate_summary(summary);
}

// List *.md files in dir (non-recursive), sorted, excluding the index target.
std::vector<std::string> list_markdown(const std::string& dir, const std::string& exclude_basename) {
  std::vector<std::string> names;
  DIR* d = opendir(dir.c_str());
  if (!d) return names;
  struct dirent* e;
  while ((e = readdir(d))) {
    if (e->d_name[0] == '.') continue;
    std::string name = e->d_name;
    if (name.size() < 4 || name.substr(name.size() - 3) != ".md") continue;
    if (name == exclude_basename) continue;
    if (name == "README.md" || name == "INDEX.md") continue;  // never index the index itself
    std::string full = dir + "/" + name;
    if (is_file(full)) names.push_back(name);
  }
  closedir(d);
  std::sort(names.begin(), names.end());
  return names;
}

// Build the generated Markdown block (between markers, inclusive).
std::string build_block(const std::vector<DocEntry>& entries) {
  std::string out;
  out += kMarkerStart;
  out += "\n";
  out += "<!-- Generated by `cpm docs index` (ADR-171). Do not edit by hand. -->\n\n";
  out += "| Document | Summary |\n";
  out += "|----------|---------|\n";
  for (const auto& e : entries) {
    out += "| [";
    out += md_cell(e.title);
    out += "](";
    out += e.filename;
    out += ") | ";
    out += md_cell(e.summary);
    out += " |\n";
  }
  out += "\n";
  out += kMarkerEnd;
  out += "\n";
  return out;
}

// Splice the generated block into existing README content between markers.
// If markers are absent, append the block. Returns the full new file content.
std::string splice_readme(const std::string& existing, const std::string& block) {
  size_t s = existing.find(kMarkerStart);
  size_t e = existing.find(kMarkerEnd);
  if (s != std::string::npos && e != std::string::npos && e > s) {
    size_t end = e + strlen(kMarkerEnd);
    // Consume a trailing newline after the end marker to avoid accumulation.
    if (end < existing.size() && existing[end] == '\n') end++;
    std::string before = existing.substr(0, s);
    std::string after = existing.substr(end);
    return before + block + after;
  }
  // No markers: append with a separating blank line.
  std::string out = existing;
  if (!out.empty() && out.back() != '\n') out += "\n";
  if (!out.empty()) out += "\n";
  out += block;
  return out;
}

}  // namespace

static int docs_index(int argc, char* argv[]) {
  std::string dir = "docs";
  bool check_mode = false;
  for (int i = 0; i < argc; i++) {
    if (strcmp(argv[i], "--check") == 0)
      check_mode = true;
    else if (strcmp(argv[i], "--llm") == 0) {
      fprintf(stderr, "cpm docs index: --llm is not implemented yet (iteration 2, ADR-171)\n");
      return 2;
    } else if (argv[i][0] != '-') {
      dir = argv[i];
    }
  }

  // Normalise: strip trailing slash.
  while (dir.size() > 1 && dir.back() == '/') dir.pop_back();

  // Never write to repository root.
  if (dir == "." || dir == "./" || dir.empty()) {
    fprintf(stderr, "cpm docs index: refusing to index the repository root; pass a docs directory\n");
    return 1;
  }
  if (!is_dir(dir)) {
    fprintf(stderr, "cpm docs index: not a directory: %s\n", dir.c_str());
    return 1;
  }

  // Target: README.md if it exists (splice into markers), else INDEX.md (owned).
  std::string readme = dir + "/README.md";
  bool use_readme = is_file(readme);
  std::string target = use_readme ? readme : (dir + "/INDEX.md");
  std::string target_basename = use_readme ? "README.md" : "INDEX.md";

  // Collect entries.
  std::vector<std::string> files = list_markdown(dir, target_basename);
  std::vector<DocEntry> entries;
  for (const auto& name : files) {
    std::string content = read_file(dir + "/" + name);
    DocEntry de;
    de.filename = name;
    extract(content, name, de.title, de.summary);
    entries.push_back(de);
  }

  std::string block = build_block(entries);

  std::string new_content;
  if (use_readme) {
    new_content = splice_readme(read_file(target), block);
  } else {
    new_content = "# Index\n\n" + block;
  }

  std::string current = is_file(target) ? read_file(target) : "";

  if (check_mode) {
    if (current == new_content) {
      printf("✓ %s is up to date (%zu entries)\n", target.c_str(), entries.size());
      return 0;
    }
    fprintf(stderr, "✗ %s is out of date — run: cpm docs index %s\n", target.c_str(), dir.c_str());
    return 1;
  }

  if (current == new_content) {
    printf("✓ %s already up to date (%zu entries)\n", target.c_str(), entries.size());
    return 0;
  }

  FILE* f = fopen(target.c_str(), "w");
  if (!f) {
    fprintf(stderr, "cpm docs index: cannot write %s\n", target.c_str());
    return 1;
  }
  fwrite(new_content.data(), 1, new_content.size(), f);
  fclose(f);
  printf("✓ wrote %s (%zu entries)\n", target.c_str(), entries.size());
  return 0;
}

int cmd_docs(int argc, char* argv[]) {
  if (argc < 1) {
    printf("Usage: cpm docs <subcommand>\n\n");
    printf("Subcommands:\n");
    printf("  index [DIR] [--check]   Generate a Markdown index of a docs directory\n");
    printf("                          (default DIR: docs). Writes into README.md\n");
    printf("                          markers if present, else INDEX.md.\n");
    return 0;
  }
  const char* sub = argv[0];
  if (strcmp(sub, "index") == 0) return docs_index(argc - 1, argv + 1);
  fprintf(stderr, "cpm docs: unknown subcommand '%s'\n", sub);
  return 1;
}
