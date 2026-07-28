#include <algorithm>
#include <array>
#include <cctype>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "commands.h"

namespace {

// Transparent hasher to allow heterogeneous lookup on string containers.
struct StringHash {
  using is_transparent = void;
  size_t operator()(std::string_view sv) const noexcept { return std::hash<std::string_view>{}(sv); }
};

struct SortOptions {
  std::string op;      // check|fix
  std::string mode;    // cpm-toml|ts-imports|lines
  std::string file;    // file path
  bool dedup = false;  // optional
  std::string alias_prefixes = "@/,~/,src/";
  std::string start_marker;
  std::string end_marker;
};

void print_usage() {
  std::cout << "Usage: cpm sort <check|fix> --mode <cpm-toml|ts-imports|lines> --file <path> [options]\n"
            << "Options:\n"
            << "  --dedup\n"
            << "  --alias-prefixes <csv>   (ts-imports mode)\n"
            << "  --start-marker <text>    (lines mode)\n"
            << "  --end-marker <text>      (lines mode)\n";
}

std::string trim(std::string_view s) {
  size_t a = 0;
  while (a < s.size() && isspace(static_cast<unsigned char>(s[a]))) a++;
  if (a == s.size()) return "";
  size_t b = s.size() - 1;
  while (b > a && isspace(static_cast<unsigned char>(s[b]))) b--;
  return std::string(s.substr(a, b - a + 1));
}

bool starts_with(const std::string& s, const std::string& pref) { return s.rfind(pref, 0) == 0; }

bool read_lines(const std::string& path, std::vector<std::string>& out) {
  std::ifstream f(path);
  if (!f) return false;
  out.clear();
  std::string line;
  while (std::getline(f, line)) out.push_back(line);
  return true;
}

bool write_lines(const std::string& path, const std::vector<std::string>& lines) {
  // Write-then-rename so an interrupted run cannot leave a truncated source file.
  const std::string tmp = path + ".cpmsort.tmp";
  {
    std::ofstream f(tmp, std::ios::trunc);
    if (!f) return false;
    for (const auto& line : lines) f << line << "\n";
    f.flush();
    if (!f.good()) {
      std::remove(tmp.c_str());
      return false;
    }
  }
  return std::rename(tmp.c_str(), path.c_str()) == 0;
}

std::vector<std::string> split_csv(const std::string& csv) {
  std::vector<std::string> out;
  std::stringstream ss(csv);
  std::string item;
  while (std::getline(ss, item, ',')) {
    item = trim(item);
    if (!item.empty()) out.push_back(item);
  }
  return out;
}

int section_rank(const std::string& s) {
  if (s == "project") return 0;
  if (s == "tools") return 1;
  if (s == "checks") return 2;
  if (starts_with(s, "checks.")) return 3;
  if (s == "hooks") return 4;
  if (s == "runner") return 5;
  if (s == "limits") return 6;
  if (s == "process") return 7;
  if (s == "issues") return 8;
  return 50;
}

bool is_sortable_section(const std::string& s) {
  return s == "tools" || s == "checks" || s == "limits" || starts_with(s, "checks.");
}

std::vector<std::string> sort_section_body_if_safe(const std::vector<std::string>& body, bool dedup) {
  static const std::regex keyval_re(R"(^\s*([A-Za-z0-9_.-]+)\s*=)");
  std::vector<std::pair<std::string, std::string>> kv;
  std::vector<std::string> comments_or_blank;

  for (const auto& line : body) {
    auto t = trim(line);
    if (t.empty() || starts_with(t, "#")) {
      comments_or_blank.push_back(line);
      continue;
    }
    std::smatch m;
    if (std::regex_search(line, m, keyval_re)) {
      kv.emplace_back(m[1].str(), line);
    } else {
      return body;  // complex section, leave unchanged
    }
  }

  if (dedup) {
    std::unordered_map<std::string, std::pair<int, std::string>, StringHash, std::equal_to<>> last;
    for (int i = 0; i < static_cast<int>(kv.size()); i++) last[kv[i].first] = {i, kv[i].second};
    kv.clear();
    kv.reserve(last.size());
    for (const auto& it : last) kv.push_back({it.first, it.second.second});
  }

  std::sort(kv.begin(), kv.end(), [](const auto& a, const auto& b) {
    if (a.first == b.first) return a.second < b.second;
    return a.first < b.first;
  });

  std::vector<std::string> out;
  out.reserve(kv.size() + comments_or_blank.size() + 1);
  for (const auto& it : kv) out.push_back(it.second);
  if (!comments_or_blank.empty() && !out.empty() && !trim(out.back()).empty()) out.push_back("");
  out.insert(out.end(), comments_or_blank.begin(), comments_or_blank.end());
  return out;
}

std::vector<std::string> canonicalize_cpm_toml(const std::vector<std::string>& lines, bool dedup) {
  static const std::regex section_re(R"(^\[([^\]]+)\]\s*$)");

  std::vector<std::string> preamble;
  std::vector<std::string> section_order;
  std::unordered_map<std::string, std::vector<std::string>, StringHash, std::equal_to<>> bodies;
  std::set<std::string> seen_sections;
  std::string cur;

  for (const auto& line : lines) {
    auto tline = trim(line);
    // Array-of-tables reordering is not modelled here; refuse to rewrite
    // rather than re-parent the block under the preceding section.
    if (starts_with(tline, "[[")) return lines;
    std::smatch m;
    if (std::regex_match(tline, m, section_re)) {
      cur = m[1].str();
      if (!seen_sections.count(cur)) {
        seen_sections.insert(cur);
        section_order.push_back(cur);
      }
      continue;
    }

    if (cur.empty())
      preamble.push_back(line);
    else
      bodies[cur].push_back(line);
  }

  std::sort(section_order.begin(), section_order.end(), [](const auto& a, const auto& b) {
    int ra = section_rank(a), rb = section_rank(b);
    if (ra != rb) return ra < rb;
    return a < b;
  });

  std::vector<std::string> out = preamble;
  if (!out.empty() && !trim(out.back()).empty()) out.push_back("");

  for (size_t i = 0; i < section_order.size(); i++) {
    const auto& sec = section_order[i];
    if (!out.empty() && !trim(out.back()).empty()) out.push_back("");

    out.push_back("[" + sec + "]");
    auto body = bodies[sec];
    if (is_sortable_section(sec)) body = sort_section_body_if_safe(body, dedup);
    out.insert(out.end(), body.begin(), body.end());

    if (i + 1 < section_order.size() && !out.empty() && !trim(out.back()).empty()) out.push_back("");
  }
  return out;
}

std::string sort_import_members(const std::string& line) {
  // Capture the quote character so member sorting never changes quote style.
  static const std::regex brace_re(R"(^\s*import\s*\{([^}]*)\}\s*from\s*(['\"])([^'\"]+)\2\s*;?\s*$)");
  std::smatch m;
  if (!std::regex_match(line, m, brace_re)) return line;

  std::vector<std::string> members;
  std::stringstream ss(m[1].str());
  std::string part;
  while (std::getline(ss, part, ',')) {
    part = trim(part);
    if (!part.empty()) members.push_back(part);
  }
  std::ranges::sort(members, [](const std::string& a, const std::string& b) {
    std::string na = starts_with(a, "type ") ? a.substr(5) : a;
    std::string nb = starts_with(b, "type ") ? b.substr(5) : b;
    if (na == nb) return a < b;
    return na < nb;
  });

  std::string joined;
  for (size_t i = 0; i < members.size(); i++) {
    if (i) joined += ", ";
    joined += members[i];
  }
  const std::string q = m[2].str();
  return "import { " + joined + " } from " + q + m[3].str() + q + ";";
}

std::string module_of_import(const std::string& line) {
  static const std::regex from_re(R"(from\s*['\"]([^'\"]+)['\"])");
  static const std::regex side_effect_re(R"(^\s*import\s*['\"]([^'\"]+)['\"]\s*;?\s*$)");
  std::smatch m;
  if (std::regex_search(line, m, from_re)) return m[1].str();
  if (std::regex_match(line, m, side_effect_re)) return m[1].str();
  return trim(line);
}

int import_group(const std::string& mod, const std::vector<std::string>& aliases) {
  if (!mod.empty() && mod[0] == '.') return 2;
  for (const auto& pref : aliases)
    if (!pref.empty() && starts_with(mod, pref)) return 1;
  return 0;
}

// Returns the index of the first import statement, or -1 if none found.
// Returns -2 if the first non-blank/non-comment line is not an import (leave file alone).
int find_import_start(const std::vector<std::string>& lines, const std::regex& import_re) {
  for (int i = 0; i < static_cast<int>(lines.size()); i++) {
    auto t = trim(lines[i]);
    if (t.empty() || starts_with(t, "//")) continue;
    return std::regex_search(lines[i], import_re) ? i : -2;
  }
  return -1;
}

// Returns the index one past the last import-block line.
int find_import_end(const std::vector<std::string>& lines, int start, const std::regex& import_re) {
  int end = start;
  for (int i = start; i < static_cast<int>(lines.size()); i++) {
    auto t = trim(lines[i]);
    if (t.empty() || starts_with(t, "//") || std::regex_search(lines[i], import_re)) {
      end = i + 1;
      continue;
    }
    break;
  }
  return end;
}

// Returns true if any import in the range spans multiple lines (cannot safely reorder).
bool has_multiline_import(const std::vector<std::string>& lines, int start, int end, const std::regex& import_re) {
  for (int i = start; i < end; i++) {
    auto t = trim(lines[i]);
    if (std::regex_search(lines[i], import_re) && !t.empty() && t.back() != ';' && t.back() != '\'' && t.back() != '"') return true;
  }
  return false;
}

struct ImportEntry {
  std::string mod;
  std::string line;
};

// Assemble sorted import block from grouped entries and trailing comments.
std::vector<std::string> assemble_sorted_block(std::array<std::vector<ImportEntry>, 3>& groups, const std::vector<std::string>& comments) {
  for (auto& group : groups) {
    std::ranges::sort(group, [](const ImportEntry& a, const ImportEntry& b) {
      if (a.mod == b.mod) return a.line < b.line;
      return a.mod < b.mod;
    });
  }

  std::vector<std::string> sorted_block;
  bool wrote = false;
  for (int g = 0; g < 3; g++) {
    if (groups[g].empty()) continue;
    if (wrote) sorted_block.emplace_back("");
    for (const auto& e : groups[g]) sorted_block.emplace_back(e.line);
    wrote = true;
  }
  if (!comments.empty()) {
    if (wrote) sorted_block.emplace_back("");
    sorted_block.insert(sorted_block.end(), comments.begin(), comments.end());
  }
  return sorted_block;
}

std::vector<std::string> canonicalize_ts_imports(const std::vector<std::string>& lines, const std::vector<std::string>& aliases) {
  static const std::regex import_re(R"(^\s*import\b)");

  int start = find_import_start(lines, import_re);
  if (start < 0) return lines;

  int end = find_import_end(lines, start, import_re);

  if (has_multiline_import(lines, start, end, import_re)) return lines;

  std::array<std::vector<ImportEntry>, 3> groups;
  std::vector<std::string> comments;

  for (int i = start; i < end; i++) {
    auto t = trim(lines[i]);
    if (t.empty()) continue;
    if (starts_with(t, "//")) {
      comments.push_back(lines[i]);
      continue;
    }
    if (!std::regex_search(lines[i], import_re)) continue;

    auto line = sort_import_members(lines[i]);
    auto mod = module_of_import(line);
    int g = import_group(mod, aliases);
    groups[g].emplace_back(ImportEntry{mod, line});
  }

  auto sorted_block = assemble_sorted_block(groups, comments);

  std::vector<std::string> out;
  out.reserve(lines.size() + 8);
  out.insert(out.end(), lines.begin(), lines.begin() + start);
  out.insert(out.end(), sorted_block.begin(), sorted_block.end());
  out.insert(out.end(), lines.begin() + end, lines.end());
  return out;
}

std::vector<std::string> sort_lines_basic(const std::vector<std::string>& in, bool dedup) {
  std::vector<std::string> vals;
  vals.reserve(in.size());
  for (const auto& line : in)
    if (!trim(line).empty()) vals.push_back(line);

  std::ranges::sort(vals);
  if (dedup) vals.erase(std::ranges::unique(vals).begin(), vals.end());
  return vals;
}

std::vector<std::string> canonicalize_lines_mode(const std::vector<std::string>& lines, bool dedup, const std::string& start_marker,
                                                        const std::string& end_marker) {
  if (start_marker.empty() || end_marker.empty()) return sort_lines_basic(lines, dedup);

  std::vector<std::string> out;
  std::vector<std::string> block;
  bool in_block = false;

  auto flush_block = [&]() {
    auto sorted = sort_lines_basic(block, dedup);
    out.insert(out.end(), sorted.begin(), sorted.end());
    block.clear();
  };

  for (const auto& line : lines) {
    if (!in_block && line.find(start_marker) != std::string::npos) {
      in_block = true;
      out.push_back(line);
      continue;
    }

    if (in_block && line.find(end_marker) != std::string::npos) {
      flush_block();
      in_block = false;
      out.push_back(line);
      continue;
    }

    if (in_block)
      block.push_back(line);
    else
      out.push_back(line);
  }
  if (in_block) {
    // An unterminated block almost always means a wrong --end-marker; sorting
    // to EOF would silently rewrite unrelated content.
    std::cerr << "unterminated block: end marker not found\n";
    return lines;
  }

  return out;
}

bool consume_arg(int& i, int argc, char* argv[], std::string& out) {
  if (i + 1 >= argc) return false;
  out = argv[++i];
  return true;
}

bool parse_args(int argc, char* argv[], SortOptions& o) {
  if (argc < 1) return false;
  o.op = argv[0];
  if (o.op != "check" && o.op != "fix") return false;

  for (int i = 1; i < argc; i++) {
    std::string a = argv[i];
    if (a == "--mode") {
      if (!consume_arg(i, argc, argv, o.mode)) return false;
    } else if (a == "--file") {
      if (!consume_arg(i, argc, argv, o.file)) return false;
    } else if (a == "--dedup") {
      o.dedup = true;
    } else if (a == "--alias-prefixes") {
      if (!consume_arg(i, argc, argv, o.alias_prefixes)) return false;
    } else if (a == "--start-marker") {
      if (!consume_arg(i, argc, argv, o.start_marker)) return false;
    } else if (a == "--end-marker") {
      if (!consume_arg(i, argc, argv, o.end_marker)) return false;
    } else {
      return false;
    }
  }

  return !o.mode.empty() && !o.file.empty();
}

}  // namespace

int cmd_sort(int argc, char* argv[]) {
  SortOptions opt;
  if (!parse_args(argc, argv, opt)) {
    print_usage();
    return 1;
  }

  std::vector<std::string> lines;
  if (!read_lines(opt.file, lines)) {
    std::cerr << "file not found or unreadable: " << opt.file << "\n";
    return 1;
  }

  std::vector<std::string> transformed;
  if (opt.mode == "cpm-toml")
    transformed = canonicalize_cpm_toml(lines, opt.dedup);
  else if (opt.mode == "ts-imports")
    transformed = canonicalize_ts_imports(lines, split_csv(opt.alias_prefixes));
  else if (opt.mode == "lines")
    transformed = canonicalize_lines_mode(lines, opt.dedup, opt.start_marker, opt.end_marker);
  else {
    print_usage();
    return 1;
  }

  bool changed = transformed != lines;
  if (opt.op == "check") {
    if (changed) {
      std::cout << "not canonical: " << opt.file << "\n";
      return 1;
    }
    std::cout << "ok: " << opt.file << "\n";
    return 0;
  }

  if (!changed) {
    std::cout << "already canonical: " << opt.file << "\n";
    return 0;
  }

  if (!write_lines(opt.file, transformed)) {
    std::cerr << "failed to write: " << opt.file << "\n";
    return 1;
  }

  std::cout << "fixed: " << opt.file << "\n";
  return 0;
}
