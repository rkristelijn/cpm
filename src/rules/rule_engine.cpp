/**
 * @file rule_engine.cpp
 * @brief Rule engine implementation — parser + RE2-powered scanner.
 * @see ADR-145
 *
 * Key performance features:
 * - Single directory walk (all files discovered once)
 * - Single file read per file (content shared across all rules)
 * - RE2 for regex (linear time, no catastrophic backtracking)
 * - Literal pre-filter (memmem-style) before regex
 * - Extension-based rule dispatch (skip irrelevant rules instantly)
 */
#include "rule_engine.h"

#include <dirent.h>
#include <sys/stat.h>

#include <algorithm>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <unordered_map>
#include <unordered_set>

#include "../analysis/tokenizer.h"  // ADR-165: comment/string stripping

// --- Helpers ---

static std::string trim(const std::string& s) {
  auto start = s.find_first_not_of(" \t\r\n");
  if (start == std::string::npos) return "";
  auto end = s.find_last_not_of(" \t\r\n");
  return s.substr(start, end - start + 1);
}

static std::vector<std::string> split(const std::string& s, char delim) {
  std::vector<std::string> parts;
  std::istringstream iss(s);
  std::string part;
  while (std::getline(iss, part, delim)) {
    auto t = trim(part);
    if (!t.empty()) parts.push_back(t);
  }
  return parts;
}

static std::string get_extension(const std::string& path) {
  auto dot = path.rfind('.');
  if (dot == std::string::npos) return "";
  return path.substr(dot);
}

static bool ends_with(const std::string& str, const std::string& suffix) {
  if (suffix.size() > str.size()) return false;
  return str.compare(str.size() - suffix.size(), suffix.size(), suffix) == 0;
}

static bool starts_with(const std::string& str, const std::string& prefix) { return str.compare(0, prefix.size(), prefix) == 0; }

// --- Rule Parser ---

Rule rule_parse(const std::string& path) {
  Rule rule;
  std::ifstream f(path);
  if (!f.is_open()) return rule;

  std::string line;
  bool in_patterns = false;
  RulePattern current_pattern;

  while (std::getline(f, line)) {
    auto trimmed = trim(line);
    if (trimmed.empty() || trimmed[0] == '#') continue;

    // Pattern sub-items
    if (in_patterns && starts_with(line, "  - regex:")) {
      if (!current_pattern.regex_str.empty()) {
        rule.patterns.push_back(std::move(current_pattern));
        current_pattern = {};
      }
      current_pattern.regex_str = trim(line.substr(line.find("regex:") + 6));
    } else if (in_patterns && starts_with(line, "    message:")) {
      current_pattern.message = trim(line.substr(line.find("message:") + 8));
    } else if (in_patterns && !starts_with(line, "  ")) {
      if (!current_pattern.regex_str.empty()) {
        rule.patterns.push_back(std::move(current_pattern));
        current_pattern = {};
      }
      in_patterns = false;
    } else if (in_patterns) {
      continue;
    }

    if (in_patterns) continue;

    // Top-level keys
    auto colon = trimmed.find(':');
    if (colon == std::string::npos) continue;

    auto key = trim(trimmed.substr(0, colon));
    auto val = trim(trimmed.substr(colon + 1));

    if (key == "id")
      rule.id = val;
    else if (key == "title")
      rule.title = val;
    else if (key == "category")
      rule.category = val;
    else if (key == "severity")
      rule.severity = val;
    else if (key == "engine")
      rule.engine = val;
    else if (key == "fix")
      rule.fix = val;
    else if (key == "extensions")
      rule.target.extensions = split(val, ' ');
    else if (key == "filenames")
      rule.target.filenames = split(val, ' ');
    else if (key == "exclude_paths")
      rule.target.exclude_paths = split(val, ' ');
    else if (key == "content_contains")
      rule.target.content_contains = val;
    else if (key == "skip_comments")
      rule.skip_comments = (val == "true" || val == "yes");
    else if (key == "skip_strings")
      rule.skip_strings = (val == "true" || val == "yes");
    else if (key == "patterns") {
      in_patterns = true;
      current_pattern = {};
    }
  }

  // Flush last pattern
  if (!current_pattern.regex_str.empty()) {
    rule.patterns.push_back(std::move(current_pattern));
  }

  return rule;
}

// --- Rule Loader ---

static void find_rule_files(const std::string& dir, std::vector<std::string>& out) {
  DIR* d = opendir(dir.c_str());
  if (!d) return;

  struct dirent* entry;
  while ((entry = readdir(d)) != nullptr) {
    std::string name = entry->d_name;
    if (name == "." || name == "..") continue;

    std::string full = dir + "/" + name;
    struct stat st;
    if (stat(full.c_str(), &st) != 0) continue;

    if (S_ISDIR(st.st_mode)) {
      find_rule_files(full, out);
    } else if (ends_with(name, ".rule")) {
      out.push_back(full);
    }
  }
  closedir(d);
}

std::vector<Rule> rules_load(const std::string& dir) {
  std::vector<Rule> rules;
  std::vector<std::string> files;
  find_rule_files(dir, files);
  std::sort(files.begin(), files.end());

  for (auto& f : files) {
    auto rule = rule_parse(f);
    if (!rule.id.empty() && !rule.patterns.empty()) {
      rules.push_back(std::move(rule));
    }
  }
  return rules;
}

// --- File matching ---

bool rule_matches_file(const Rule& rule, const std::string& rel_path) {
  // Check extensions and filenames (either can match)
  bool has_ext_filter = !rule.target.extensions.empty();
  bool has_name_filter = !rule.target.filenames.empty();

  if (has_ext_filter || has_name_filter) {
    bool match = false;

    if (has_ext_filter) {
      auto ext = get_extension(rel_path);
      for (auto& e : rule.target.extensions) {
        if (ext == e) {
          match = true;
          break;
        }
      }
    }

    if (!match && has_name_filter) {
      // Extract basename from rel_path
      auto slash = rel_path.rfind('/');
      std::string basename = (slash == std::string::npos) ? rel_path : rel_path.substr(slash + 1);
      for (auto& fn : rule.target.filenames) {
        if (basename == fn) {
          match = true;
          break;
        }
      }
    }

    if (!match) return false;
  }

  for (auto& excl : rule.target.exclude_paths) {
    if (rel_path.find(excl) != std::string::npos) return false;
  }

  return true;
}

// --- Scanner ---

static void walk_files(const std::string& dir_path, const std::string& prefix, std::vector<std::string>& out) {
  DIR* d = opendir(dir_path.c_str());
  if (!d) return;

  struct dirent* entry;
  while ((entry = readdir(d)) != nullptr) {
    std::string name = entry->d_name;
    if (name == "." || name == "..") continue;

    // Skip known non-source directories (build output, dependencies, caches).
    // This is the central exclude list — per-rule exclude_paths adds rule-specific filtering on top.
    if (name[0] == '.' && name != ".github" && name != ".gitlab" && name != ".ci") continue;  // hidden dirs (except CI config)
    if (name == "node_modules" || name == "vendor" || name == "build" || name == "dist" || name == "out" || name == "output" ||
        name == "target" || name == "coverage" || name == "storybook-static" || name == "__pycache__" ||
        name == "venv" || name == "env" ||
        name == "bin" || name == "obj" ||                   // C#
        name == "_next" || name == "__next-on-pages-dist__" || // Next.js build output
        name == "_tmp" || name == "tmp" ||                  // temp/artifact dirs
        name == "example-app")                              // bundled example apps
      continue;

    std::string rel = prefix.empty() ? name : prefix + "/" + name;
    std::string full = dir_path + "/" + name;

    struct stat st;
    if (stat(full.c_str(), &st) != 0) continue;

    if (S_ISDIR(st.st_mode)) {
      walk_files(full, rel, out);
    } else if (S_ISREG(st.st_mode)) {
      // 1MB threshold: skip scanning files at or above 1MB to prevent excessive memory usage and slow RE2 pattern matching on giant
      // binaries or log files.
      if (st.st_size < 1024 * 1024) {
        out.push_back(rel);
      } else {
        std::cerr << "Warning: skipping oversized file '" << rel << "' (" << st.st_size << " bytes, exceeds 1MB limit)\n";
      }
    }
  }
  closedir(d);
}

std::vector<RuleFinding> rules_scan(const std::vector<Rule>& rules, const std::string& root) {
  std::vector<RuleFinding> findings;

  // Build extension → rules index and filename → rules index.
  // Rules with no extensions AND no filenames go into a catch-all bucket applied to every file,
  // matching the "match all files" contract of rule_matches_file().
  std::unordered_map<std::string, std::vector<const Rule*>> ext_index;
  std::unordered_map<std::string, std::vector<const Rule*>> name_index;
  std::vector<const Rule*> all_ext_rules;  // rules with no extension/filename filter
  for (auto& rule : rules) {
    if (rule.target.extensions.empty() && rule.target.filenames.empty()) {
      all_ext_rules.push_back(&rule);
    } else {
      for (auto& ext : rule.target.extensions) {
        ext_index[ext].push_back(&rule);
      }
      for (auto& fn : rule.target.filenames) {
        name_index[fn].push_back(&rule);
      }
    }
  }

  // Pre-compile all RE2 patterns per rule
  struct CompiledRule {
    const Rule* rule;
    std::vector<std::unique_ptr<RE2>> patterns;
  };
  std::vector<CompiledRule> compiled;
  compiled.reserve(rules.size());
  for (auto& rule : rules) {
    CompiledRule cr;
    cr.rule = &rule;
    for (auto& pat : rule.patterns) {
      auto re = std::make_unique<RE2>(pat.regex_str);
      if (re->ok()) {
        cr.patterns.push_back(std::move(re));
      } else {
        std::cerr << "Warning: invalid regex '" << pat.regex_str << "' in rule '" << rule.id << "': " << re->error() << "\n";
        cr.patterns.push_back(nullptr);  // placeholder for bad regex
      }
    }
    compiled.push_back(std::move(cr));
  }

  // Build rule pointer → compiled index
  std::unordered_map<const Rule*, size_t> rule_to_compiled;
  for (size_t i = 0; i < compiled.size(); i++) {
    rule_to_compiled[compiled[i].rule] = i;
  }

  // Walk all files once
  std::vector<std::string> files;
  walk_files(root, "", files);
  std::sort(files.begin(), files.end());

  // For each file, run all matching rules
  for (auto& rel_path : files) {
    auto ext = get_extension(rel_path);
    auto it = ext_index.find(ext);

    // Extract basename for filename matching
    auto slash = rel_path.rfind('/');
    std::string basename = (slash == std::string::npos) ? rel_path : rel_path.substr(slash + 1);
    auto nit = name_index.find(basename);

    // Combine catch-all rules with extension-specific and filename-specific rules
    std::vector<const Rule*> candidates = all_ext_rules;
    if (it != ext_index.end()) {
      candidates.insert(candidates.end(), it->second.begin(), it->second.end());
    }
    if (nit != name_index.end()) {
      candidates.insert(candidates.end(), nit->second.begin(), nit->second.end());
    }
    if (candidates.empty()) continue;

    // Filter rules by exclude paths
    std::vector<const Rule*> applicable;
    for (auto* rule : candidates) {
      bool excluded = false;
      for (auto& excl : rule->target.exclude_paths) {
        if (rel_path.find(excl) != std::string::npos) {
          excluded = true;
          break;
        }
      }
      if (!excluded) applicable.push_back(rule);
    }
    if (applicable.empty()) continue;

    // Read file content once
    std::string full = root + "/" + rel_path;
    std::ifstream f(full);
    if (!f.is_open()) continue;
    std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());

    // Pre-filter: check content_contains (literal, O(n) scan)
    std::vector<const Rule*> filtered;
    for (auto* rule : applicable) {
      if (rule->target.content_contains.empty() || content.find(rule->target.content_contains) != std::string::npos) {
        filtered.push_back(rule);
      }
    }
    if (filtered.empty()) continue;

    // ADR-165: Prepare comment/string-stripped content if any rule needs it.
    // Lazy: only tokenize if at least one applicable rule uses skip_comments or skip_strings.
    bool need_stripped_comments = false;
    bool need_stripped_strings = false;
    for (auto* rule : filtered) {
      if (rule->skip_comments) need_stripped_comments = true;
      if (rule->skip_strings) need_stripped_strings = true;
    }

    std::string stripped_content;
    std::vector<re2::StringPiece> stripped_lines;
    bool has_stripped = false;

    if (need_stripped_comments || need_stripped_strings) {
      auto* syntax = lang_syntax(ext);
      if (syntax) {
        if (need_stripped_strings)
          stripped_content = strip_comments_and_strings(content, syntax);
        else
          stripped_content = strip_comments(content, syntax);
        has_stripped = true;

        // Split stripped content into lines (same structure as original)
        const char* sp = stripped_content.data();
        const char* send = sp + stripped_content.size();
        const char* sline_start = sp;
        while (sp <= send) {
          if (sp == send || *sp == '\n') {
            stripped_lines.emplace_back(sline_start, sp - sline_start);
            sline_start = sp + 1;
          }
          sp++;
        }
      }
    }

    // Split original into lines
    std::vector<re2::StringPiece> lines;
    const char* p = content.data();
    const char* end = p + content.size();
    const char* line_start = p;
    while (p <= end) {
      if (p == end || *p == '\n') {
        lines.emplace_back(line_start, p - line_start);
        line_start = p + 1;
      }
      p++;
    }

    // Evaluate each rule according to its specified engine
    for (auto* rule : filtered) {
      auto ci = rule_to_compiled.find(rule);
      if (ci == rule_to_compiled.end()) continue;
      auto& cr = compiled[ci->second];

      // ADR-165: Use stripped lines if rule requests comment/string skipping
      auto& scan_lines = (has_stripped && (rule->skip_comments || rule->skip_strings)) ? stripped_lines : lines;

      if (rule->engine == "pattern" || rule->engine.empty()) {
        for (size_t pi = 0; pi < cr.patterns.size(); pi++) {
          if (!cr.patterns[pi]) continue;  // bad regex
          auto& re = *cr.patterns[pi];

          for (size_t li = 0; li < scan_lines.size(); li++) {
            if (RE2::PartialMatch(scan_lines[li], re)) {
              auto& pat = rule->patterns[pi];
              findings.push_back(
                  {rule->id, rule->severity, rel_path, (int)(li + 1), pat.message.empty() ? rule->title : pat.message, rule->fix});
            }
          }
        }
      } else if (rule->engine == "absence") {
        for (size_t pi = 0; pi < cr.patterns.size(); pi++) {
          if (!cr.patterns[pi]) continue;  // bad regex
          auto& re = *cr.patterns[pi];

          bool found = false;
          for (size_t li = 0; li < scan_lines.size(); li++) {
            if (RE2::PartialMatch(scan_lines[li], re)) {
              found = true;
              break;
            }
          }
          if (!found) {
            auto& pat = rule->patterns[pi];
            findings.push_back({rule->id, rule->severity, rel_path, 1, pat.message.empty() ? rule->title : pat.message, rule->fix});
          }
        }
      } else if (rule->engine == "presence") {
        for (size_t pi = 0; pi < cr.patterns.size(); pi++) {
          if (!cr.patterns[pi]) continue;  // bad regex
          auto& re = *cr.patterns[pi];

          for (size_t li = 0; li < scan_lines.size(); li++) {
            if (RE2::PartialMatch(scan_lines[li], re)) {
              auto& pat = rule->patterns[pi];
              findings.push_back(
                  {rule->id, rule->severity, rel_path, (int)(li + 1), pat.message.empty() ? rule->title : pat.message, rule->fix});
              break;  // Report first occurrence in file for presence check
            }
          }
        }
      } else {
        static std::unordered_set<std::string> warned_engines;
        if (warned_engines.insert(rule->engine).second) {
          std::cerr << "Warning: unsupported rule engine '" << rule->engine << "' for rule '" << rule->id << "'\n";
        }
      }
    }
  }

  return findings;
}
