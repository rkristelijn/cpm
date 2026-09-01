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
#include <string_view>
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
    else if (key == "scope") {
      // ADR-166: parse "start-end" (1-indexed, inclusive)
      auto dash = val.find('-');
      if (dash != std::string::npos) {
        rule.target.scope_start = std::stoi(val.substr(0, dash));
        rule.target.scope_end = std::stoi(val.substr(dash + 1));
      }
    } else if (key == "extract") {
      // ADR-166 phase 5: extract-duplicates regex (read verbatim after "extract: ")
      rule.extract_regex = val;
    } else if (key == "capture") {
      rule.extract_capture = std::stoi(val);
    } else if (key == "message") {
      rule.extract_message = val;
    } else if (key == "patterns") {
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
    if (!rule.id.empty() && (!rule.patterns.empty() || rule.engine == "file-absence" || rule.engine == "file-presence" || rule.engine == "extract-duplicates")) {
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
        // Support compound extensions: ".test.js" matches "app.test.js"
        if (ext == e || ends_with(rel_path, e)) {
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

// --- Engine evaluators (ADR-166: decomposed from rules_scan) ---

struct CompiledRule {
  const Rule* rule = nullptr;
  std::vector<std::unique_ptr<RE2>> patterns;
};

/**
 * @brief True if any whitespace/`,`-separated token in `rest` is EXACTLY equal
 * to `rule_id` or `category`. Using exact token equality (not substring find)
 * ensures `SEC-04` does not suppress `SEC-043`. @see docs/designs/rule-engine-config.md
 */
static bool tokens_match(const std::string& rest, const std::string& rule_id, const std::string& category) {
  size_t i = 0, n = rest.size();
  while (i < n) {
    // Skip separators.
    while (i < n && (rest[i] == ' ' || rest[i] == '\t' || rest[i] == ',')) i++;
    size_t start = i;
    while (i < n && rest[i] != ' ' && rest[i] != '\t' && rest[i] != ',') i++;
    if (i > start) {
      std::string tok = rest.substr(start, i - start);
      if (!rule_id.empty() && tok == rule_id) return true;
      if (!category.empty() && tok == category) return true;
    }
  }
  return false;
}

/**
 * @brief Returns true if `line` is a whole-file suppression directive
 * (`cpm:ignore-file`) matching the given rule id or category. A bare
 * `cpm:ignore-file` suppresses every rule in the file — used for detector
 * source, test fixtures, and check documentation whose entire purpose is to
 * contain the patterns being detected. @see docs/designs/rule-engine-config.md
 */
static bool line_suppresses_file(re2::StringPiece line, const std::string& rule_id, const std::string& category) {
  std::string s(line.data(), line.size());
  size_t pos = s.find("cpm:ignore-file");
  if (pos == std::string::npos) return false;
  std::string rest = s.substr(pos + 15);
  size_t start = rest.find_first_not_of(" \t:,");
  if (start == std::string::npos) return true;  // bare directive suppresses all
  rest = rest.substr(start);
  return tokens_match(rest, rule_id, category);
}

/**
 * @brief Returns true if `line` suppresses a finding for the given rule id or
 * category via an inline `cpm:ignore <id>` or `cpm:ignore <category>`
 * annotation. A bare `cpm:ignore` suppresses any rule on that line.
 */
static bool line_suppresses(re2::StringPiece line, const std::string& rule_id, const std::string& category) {
  std::string s(line.data(), line.size());
  size_t pos = s.find("cpm:ignore");
  if (pos == std::string::npos) return false;
  // `cpm:ignore-file` is handled separately; skip it as a line-level marker.
  if (s.compare(pos, 15, "cpm:ignore-file") == 0) {
    pos = s.find("cpm:ignore", pos + 15);
    if (pos == std::string::npos) return false;
  }
  std::string rest = s.substr(pos + 10);
  size_t start = rest.find_first_not_of(" \t:,");
  if (start == std::string::npos) return true;  // bare `cpm:ignore` suppresses all
  rest = rest.substr(start);
  return tokens_match(rest, rule_id, category);
}

static void eval_pattern(const Rule* rule, const CompiledRule& cr,
                         const std::vector<re2::StringPiece>& scan_lines,
                         size_t lo, size_t hi, const std::string& rel_path,
                         std::vector<RuleFinding>& findings) {
  for (size_t pi = 0; pi < cr.patterns.size(); pi++) {
    if (!cr.patterns[pi]) continue;
    auto& re = *cr.patterns[pi];
    for (size_t li = lo; li < hi; li++) {
      if (RE2::PartialMatch(scan_lines[li], re)) {
        auto& pat = rule->patterns[pi];
        findings.push_back({rule->id, rule->severity, rel_path, (int)(li + 1),
                            pat.message.empty() ? rule->title : pat.message, rule->fix});
      }
    }
  }
}

static void eval_absence(const Rule* rule, const CompiledRule& cr,
                          const std::vector<re2::StringPiece>& scan_lines,
                          size_t lo, size_t hi, const std::string& rel_path,
                          std::vector<RuleFinding>& findings) {
  for (size_t pi = 0; pi < cr.patterns.size(); pi++) {
    if (!cr.patterns[pi]) continue;
    auto& re = *cr.patterns[pi];
    bool found = false;
    for (size_t li = lo; li < hi; li++) {
      if (RE2::PartialMatch(scan_lines[li], re)) { found = true; break; }
    }
    if (!found) {
      auto& pat = rule->patterns[pi];
      findings.push_back({rule->id, rule->severity, rel_path, 1,
                          pat.message.empty() ? rule->title : pat.message, rule->fix});
    }
  }
}

static void eval_presence(const Rule* rule, const CompiledRule& cr,
                           const std::vector<re2::StringPiece>& scan_lines,
                           size_t lo, size_t hi, const std::string& rel_path,
                           std::vector<RuleFinding>& findings) {
  for (size_t pi = 0; pi < cr.patterns.size(); pi++) {
    if (!cr.patterns[pi]) continue;
    auto& re = *cr.patterns[pi];
    for (size_t li = lo; li < hi; li++) {
      if (RE2::PartialMatch(scan_lines[li], re)) {
        auto& pat = rule->patterns[pi];
        findings.push_back({rule->id, rule->severity, rel_path, (int)(li + 1),
                            pat.message.empty() ? rule->title : pat.message, rule->fix});
        break;
      }
    }
  }
}

static void eval_extract_duplicates(const Rule* rule,
                                     const std::vector<re2::StringPiece>& scan_lines,
                                     size_t lo, size_t hi, const std::string& rel_path,
                                     std::vector<RuleFinding>& findings) {
  if (rule->extract_regex.empty()) return;
  RE2 extract_re(rule->extract_regex);
  if (!extract_re.ok()) return;

  std::unordered_map<std::string, std::vector<int>> occurrences;
  for (size_t li = lo; li < hi; li++) {
    re2::StringPiece input(scan_lines[li]);
    std::string captured;
    while (RE2::FindAndConsume(&input, extract_re, &captured)) {
      occurrences[captured].push_back((int)(li + 1));
    }
  }

  for (auto& [val, line_nums] : occurrences) {
    if (line_nums.size() > 1) {
      std::string msg = rule->extract_message;
      auto pos = msg.find("{match}");
      if (pos != std::string::npos) msg.replace(pos, 7, val);
      for (int ln : line_nums) {
        findings.push_back({rule->id, rule->severity, rel_path, ln, msg, rule->fix});
      }
    }
  }
}

static void eval_file_level_rules(const std::vector<const Rule*>& absence_rules,
                                   const std::vector<const Rule*>& presence_rules,
                                   const std::vector<std::string>& files,
                                   std::vector<RuleFinding>& findings) {
  std::unordered_set<std::string> walked_basenames;
  for (auto& f : files) {
    auto slash = f.rfind('/');
    walked_basenames.insert(slash == std::string::npos ? f : f.substr(slash + 1));
  }

  for (auto* rule : absence_rules) {
    bool found = false;
    for (auto& fn : rule->target.filenames) {
      if (walked_basenames.count(fn)) { found = true; break; }
    }
    if (!found) {
      for (auto& ext : rule->target.extensions) {
        for (auto& f : files) {
          if (get_extension(f) == ext && rule_matches_file(*rule, f)) { found = true; break; }
        }
        if (found) break;
      }
    }
    if (!found) {
      std::string expected = rule->target.filenames.empty()
          ? (rule->target.extensions.empty() ? "matching file" : rule->target.extensions[0])
          : rule->target.filenames[0];
      findings.push_back({rule->id, rule->severity, expected, 0, rule->title, rule->fix});
    }
  }

  for (auto* rule : presence_rules) {
    for (auto& f : files) {
      if (rule_matches_file(*rule, f)) {
        findings.push_back({rule->id, rule->severity, f, 0, rule->title, rule->fix});
      }
    }
  }
}

// --- Scanner ---

std::vector<RuleFinding> rules_scan(const std::vector<Rule>& rules, const std::string& root) {
  std::vector<RuleFinding> findings;

  // ADR-166: Separate file-level rules from content-scanning rules
  std::vector<const Rule*> file_absence_rules;
  std::vector<const Rule*> file_presence_rules;
  std::vector<const Rule*> content_rules;
  for (auto& rule : rules) {
    if (rule.engine == "file-absence")
      file_absence_rules.push_back(&rule);
    else if (rule.engine == "file-presence")
      file_presence_rules.push_back(&rule);
    else
      content_rules.push_back(&rule);
  }

  // Build extension → rules index
  std::unordered_map<std::string, std::vector<const Rule*>> ext_index;
  std::unordered_map<std::string, std::vector<const Rule*>> name_index;
  std::vector<const Rule*> all_ext_rules;
  for (auto* rule : content_rules) {
    if (rule->target.extensions.empty() && rule->target.filenames.empty()) {
      all_ext_rules.push_back(rule);
    } else {
      for (auto& ext : rule->target.extensions) ext_index[ext].push_back(rule);
      for (auto& fn : rule->target.filenames) name_index[fn].push_back(rule);
    }
  }

  // Pre-compile RE2 patterns
  std::vector<CompiledRule> compiled;
  compiled.reserve(content_rules.size());
  for (auto* rule : content_rules) {
    CompiledRule cr;
    cr.rule = rule;
    for (auto& pat : rule->patterns) {
      auto re = std::make_unique<RE2>(pat.regex_str);
      if (re->ok()) {
        cr.patterns.push_back(std::move(re));
      } else {
        std::cerr << "Warning: invalid regex '" << pat.regex_str << "' in rule '" << rule->id << "': " << re->error() << "\n";
        cr.patterns.push_back(nullptr);
      }
    }
    compiled.push_back(std::move(cr));
  }
  std::unordered_map<const Rule*, size_t> rule_to_compiled;
  for (size_t i = 0; i < compiled.size(); i++) rule_to_compiled[compiled[i].rule] = i;

  // Map rule id -> category, for inline `cpm:ignore <id|category>` suppression.
  std::unordered_map<std::string, std::string> id_to_category;
  for (const auto& r : rules) id_to_category[r.id] = r.category;

  // Walk all files once
  std::vector<std::string> files;
  walk_files(root, "", files);
  std::sort(files.begin(), files.end());

  // ADR-166: Evaluate file-level rules
  size_t file_level_before = findings.size();
  eval_file_level_rules(file_absence_rules, file_presence_rules, files, findings);

  // Apply whole-file `cpm:ignore-file <rule-id|category>` suppression to
  // file-level findings too (reusing the same directive logic as content
  // findings). Only meaningful when the target file exists and is readable
  // (file-presence findings); file-absence findings reference a missing file,
  // so there is nothing to scan. @see docs/designs/rule-engine-config.md
  if (findings.size() > file_level_before) {
    std::vector<RuleFinding> kept;
    kept.reserve(findings.size() - file_level_before);
    for (size_t i = file_level_before; i < findings.size(); i++) {
      const auto& fnd = findings[i];
      const std::string& cat = id_to_category[fnd.rule_id];
      bool suppressed = false;
      std::ifstream in(root + "/" + fnd.file);
      if (in) {
        std::string fline;
        while (std::getline(in, fline)) {
          if (line_suppresses_file(re2::StringPiece(fline.data(), fline.size()), fnd.rule_id, cat)) {
            suppressed = true;
            break;
          }
        }
      }
      if (!suppressed) kept.push_back(fnd);
    }
    findings.resize(file_level_before);
    for (auto& k : kept) findings.push_back(std::move(k));
  }

  // For each file, run all matching content rules
  for (auto& rel_path : files) {
    auto ext = get_extension(rel_path);
    auto slash = rel_path.rfind('/');
    std::string basename = (slash == std::string::npos) ? rel_path : rel_path.substr(slash + 1);

    // Combine applicable rules (check both simple and compound extensions)
    std::vector<const Rule*> candidates = all_ext_rules;
    auto eit = ext_index.find(ext);
    if (eit != ext_index.end()) candidates.insert(candidates.end(), eit->second.begin(), eit->second.end());
    // Compound extensions: ".test.js" won't be in ext_index under ".js", so check all compound keys
    for (auto& [key, rules_vec] : ext_index) {
      if (key != ext && key.size() > ext.size() && ends_with(rel_path, key)) {
        candidates.insert(candidates.end(), rules_vec.begin(), rules_vec.end());
      }
    }
    auto nit = name_index.find(basename);
    if (nit != name_index.end()) candidates.insert(candidates.end(), nit->second.begin(), nit->second.end());
    if (candidates.empty()) continue;

    // Filter by exclude paths
    std::vector<const Rule*> applicable;
    for (auto* rule : candidates) {
      bool excluded = false;
      for (auto& excl : rule->target.exclude_paths) {
        if (rel_path.find(excl) != std::string::npos) { excluded = true; break; }
      }
      if (!excluded) applicable.push_back(rule);
    }
    if (applicable.empty()) continue;

    // Read file content once
    std::ifstream f(root + "/" + rel_path);
    if (!f.is_open()) continue;
    std::string content((std::istreambuf_iterator<char>(f)), std::istreambuf_iterator<char>());

    // Pre-filter by content_contains
    std::vector<const Rule*> filtered;
    for (auto* rule : applicable) {
      if (rule->target.content_contains.empty() || content.find(rule->target.content_contains) != std::string::npos)
        filtered.push_back(rule);
    }
    if (filtered.empty()) continue;

    // ADR-165: Prepare stripped content if needed
    bool need_stripped_comments = false, need_stripped_strings = false;
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
        stripped_content = need_stripped_strings ? strip_comments_and_strings(content, syntax) : strip_comments(content, syntax);
        has_stripped = true;
        const char* sp = stripped_content.data();
        const char* send = sp + stripped_content.size();
        const char* sls = sp;
        while (sp <= send) {
          if (sp == send || *sp == '\n') { stripped_lines.emplace_back(sls, sp - sls); sls = sp + 1; }
          sp++;
        }
      }
    }

    // Split original into lines
    std::vector<re2::StringPiece> lines;
    const char* p = content.data();
    const char* end = p + content.size();
    const char* ls = p;
    while (p <= end) {
      if (p == end || *p == '\n') { lines.emplace_back(ls, p - ls); ls = p + 1; }
      p++;
    }

    // Dispatch to engine evaluators
    size_t findings_before = findings.size();
    for (auto* rule : filtered) {
      auto& scan_lines = (has_stripped && (rule->skip_comments || rule->skip_strings)) ? stripped_lines : lines;

      size_t lo = 0, hi = scan_lines.size();
      if (rule->target.scope_start > 0 && rule->target.scope_end > 0) {
        lo = (size_t)(rule->target.scope_start - 1);
        hi = std::min((size_t)rule->target.scope_end, scan_lines.size());
        if (lo >= scan_lines.size()) continue;
      }

      if (rule->engine == "pattern" || rule->engine.empty()) {
        auto ci = rule_to_compiled.find(rule);
        if (ci != rule_to_compiled.end()) eval_pattern(rule, compiled[ci->second], scan_lines, lo, hi, rel_path, findings);
      } else if (rule->engine == "absence") {
        auto ci = rule_to_compiled.find(rule);
        if (ci != rule_to_compiled.end()) eval_absence(rule, compiled[ci->second], scan_lines, lo, hi, rel_path, findings);
      } else if (rule->engine == "presence") {
        auto ci = rule_to_compiled.find(rule);
        if (ci != rule_to_compiled.end()) eval_presence(rule, compiled[ci->second], scan_lines, lo, hi, rel_path, findings);
      } else if (rule->engine == "extract-duplicates") {
        eval_extract_duplicates(rule, scan_lines, lo, hi, rel_path, findings);
      } else {
        static std::unordered_set<std::string> warned_engines;
        if (warned_engines.insert(rule->engine).second) {
          std::cerr << "Warning: unsupported rule engine '" << rule->engine << "' for rule '" << rule->id << "'\n";
        }
      }
    }

    // Inline suppression: drop findings suppressed by a whole-file
    // `cpm:ignore-file` directive or a same-line `cpm:ignore` annotation. Uses
    // raw `lines` so annotations are visible even when the rule scanned
    // stripped content. Same-line only for `cpm:ignore` to avoid leaking
    // suppression to an adjacent unrelated line.
    if (findings.size() > findings_before) {
      std::vector<size_t> file_directive_lines;
      for (size_t li = 0; li < lines.size(); li++) {
        re2::StringPiece l = lines[li];
        std::string_view lv(l.data(), l.size());
        if (lv.find("cpm:ignore-file") != std::string_view::npos) file_directive_lines.push_back(li);
      }
      std::vector<RuleFinding> kept;
      kept.reserve(findings.size() - findings_before);
      for (size_t i = findings_before; i < findings.size(); i++) {
        const auto& fnd = findings[i];
        const std::string& cat = id_to_category[fnd.rule_id];
        bool suppressed = false;
        for (size_t dl : file_directive_lines) {
          if (line_suppresses_file(lines[dl], fnd.rule_id, cat)) { suppressed = true; break; }
        }
        if (!suppressed && fnd.line >= 1 && (size_t)fnd.line <= lines.size())
          suppressed = line_suppresses(lines[fnd.line - 1], fnd.rule_id, cat);
        if (!suppressed) kept.push_back(fnd);
      }
      findings.resize(findings_before);
      for (auto& k : kept) findings.push_back(std::move(k));
    }
  }

  return findings;
}
