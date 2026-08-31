/**
 * @file dup_symbols.cpp
 * @brief Generic duplicate-symbol detection (see dup_symbols.h).
 *
 * Pipeline: extract → normalize → group_by(hash) → filter(count>1) → report.
 * Body-hash based, language-agnostic. Reuses the tokenizer for normalization.
 *
 * @see ADR-170, ADR-166
 */
#include "dup_symbols.h"

#include <sys/stat.h>

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstring>
#include <dirent.h>
#include <functional>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <vector>

#include "constants.h"
#include "platform.h"
#include "tokenizer.h"

/* ── Source extensions we analyse (C-family; the body extractor is brace-based) ── */
static const std::set<std::string> DUP_EXTENSIONS = {".c", ".cc", ".cpp", ".cxx", ".h", ".hpp", ".hh"};

/* ── Directories to skip (mirrors import_graph.cpp / scan.cpp) ── */
static bool should_skip_dir(const char* name) {
  return std::strcmp(name, "node_modules") == 0 || std::strcmp(name, ".git") == 0 ||
         std::strcmp(name, "build") == 0 || std::strcmp(name, "dist") == 0 ||
         std::strcmp(name, "target") == 0 || std::strcmp(name, ".cache") == 0 ||
         std::strcmp(name, "vendor") == 0 || std::strcmp(name, ".tmp") == 0 ||
         std::strcmp(name, "out") == 0 || std::strcmp(name, ".next") == 0 ||
         std::strcmp(name, "coverage") == 0 || std::strcmp(name, "__pycache__") == 0;
}

static std::string get_extension(const std::string& path) {
  auto dot = path.rfind('.');
  if (dot == std::string::npos) return "";
  return path.substr(dot);
}

static std::string read_file(const std::string& path) {
  FILE* f = std::fopen(path.c_str(), "r");
  if (!f) return "";
  std::string content;
  char buf[CPM_READ_BUF];
  size_t n;
  while ((n = std::fread(buf, 1, sizeof(buf), f)) > 0) content.append(buf, n);
  std::fclose(f);
  return content;
}

static void find_source_files(const std::string& dir, std::vector<std::string>& out) {
  DIR* d = opendir(dir.c_str());
  if (!d) return;
  struct dirent* entry;
  while ((entry = readdir(d)) != nullptr) {
    if (entry->d_name[0] == '.') continue;
    std::string full = dir + "/" + entry->d_name;
    /* Skip symlinks so a directory symlink (loop -> .) cannot recurse forever.
     * platform::is_symlink keeps this portable (ADR-170). */
    if (platform::is_symlink(full)) continue;
    struct stat st;
    if (stat(full.c_str(), &st) != 0) continue;
    if (S_ISDIR(st.st_mode)) {
      if (!should_skip_dir(entry->d_name)) find_source_files(full, out);
    } else if (S_ISREG(st.st_mode)) {
      if (DUP_EXTENSIONS.count(get_extension(entry->d_name))) out.push_back(full);
    }
  }
  closedir(d);
}

static std::string make_relative(const std::string& path, const std::string& root) {
  if (path.size() > root.size() && path.substr(0, root.size()) == root) {
    size_t start = root.size();
    while (start < path.size() && path[start] == '/') start++;
    return path.substr(start);
  }
  return path;
}

/* ── Normalization: produce a canonical token stream ──
 * The caller has already stripped comments and strings via the tokenizer.
 * We further canonicalise spacing so that formatting differences (e.g.
 * "x*2" vs "x * 2", or tabs vs spaces) do not defeat comparison: every
 * run of whitespace becomes nothing, and identifier/number boundaries get a
 * single separating space. Two byte-identical results are genuine copies
 * regardless of indentation or operator spacing. */
static std::string normalize_body(const std::string& s) {
  std::string out;
  out.reserve(s.size());
  auto is_word = [](char c) { return std::isalnum(static_cast<unsigned char>(c)) || c == '_'; };
  bool prev_word = false;
  for (size_t i = 0; i < s.size(); i++) {
    char c = s[i];
    if (std::isspace(static_cast<unsigned char>(c))) continue;  // drop all whitespace
    bool cur_word = is_word(c);
    // Insert a boundary space only between two adjacent word chars that a
    // dropped whitespace used to separate (keeps "int x" != "intx").
    if (cur_word && prev_word && !out.empty()) {
      // Was there whitespace between the previous kept char and this one?
      // We only get here if the immediately preceding source char(s) were
      // whitespace (since non-ws word chars are emitted contiguously).
      if (i > 0 && std::isspace(static_cast<unsigned char>(s[i - 1]))) out.push_back(' ');
    }
    out.push_back(c);
    prev_word = cur_word;
  }
  return out;
}

/* ── Count 1-based line number at byte offset ── */
static int line_at(const std::string& s, size_t off) {
  int line = 1;
  for (size_t i = 0; i < off && i < s.size(); i++)
    if (s[i] == '\n') line++;
  return line;
}

static bool is_ident_char(char c) {
  return std::isalnum(static_cast<unsigned char>(c)) || c == '_';
}

/* ── Read the identifier ending just before position `end` (skipping ws) ── */
static std::string ident_before(const std::string& s, size_t end) {
  while (end > 0 && std::isspace(static_cast<unsigned char>(s[end - 1]))) end--;
  size_t stop = end;
  while (stop > 0 && is_ident_char(s[stop - 1])) stop--;
  return s.substr(stop, end - stop);
}

/* ─────────────────────────────────────────────────────────────
 * Pipeline stage 1: extract
 * Brace-based function extraction over comment/string-stripped code.
 * A function is: <identifier> ( ... ) [qualifiers] { ... balanced ... }
 * File-scope variables: a top-level `= ...;` or `identifier ... ;` with no
 * enclosing brace and containing an assignment.
 * ───────────────────────────────────────────────────────────── */
std::vector<Symbol> extract_symbols(const std::string& content, const std::string& extension,
                                    const std::string& file) {
  std::vector<Symbol> out;
  const LangSyntax* syntax = lang_syntax(extension);
  if (!syntax) return out;

  // Stripped view for scanning; original kept for line numbers.
  std::string code = strip_comments_and_strings(content, syntax);

  int brace_depth = 0;
  size_t i = 0;
  const size_t n = code.size();

  while (i < n) {
    char c = code[i];

    if (c == '{') { brace_depth++; i++; continue; }
    if (c == '}') { if (brace_depth > 0) brace_depth--; i++; continue; }

    // Only detect definitions at file scope (depth 0).
    if (brace_depth == 0 && c == '(') {
      // Candidate function: identifier immediately before '('.
      std::string name = ident_before(code, i);
      if (!name.empty() && !std::isdigit(static_cast<unsigned char>(name[0]))) {
        // Find matching ')'.
        int paren = 0;
        size_t j = i;
        for (; j < n; j++) {
          if (code[j] == '(') paren++;
          else if (code[j] == ')') { paren--; if (paren == 0) { j++; break; } }
        }
        // Skip qualifiers/whitespace to the next significant char.
        size_t k = j;
        while (k < n && code[k] != '{' && code[k] != ';') k++;
        if (k < n && code[k] == '{') {
          // Balanced body.
          int b = 0;
          size_t body_start = k;
          size_t m = k;
          for (; m < n; m++) {
            if (code[m] == '{') b++;
            else if (code[m] == '}') { b--; if (b == 0) { m++; break; } }
          }
          std::string body = code.substr(body_start, m - body_start);
          std::string norm = normalize_body(body);
          // Ignore trivial/empty bodies ("{ }") — too common to be meaningful.
          if (norm.size() > 4) {
            Symbol sym;
            sym.kind = SymbolKind::Function;
            sym.name = name;
            sym.file = file;
            sym.line = line_at(content, i);
            sym.norm_body = norm;
            sym.body_hash = std::hash<std::string>{}(norm);
            out.push_back(std::move(sym));
          }
          i = m;
          continue;
        }
        i = j;
        continue;
      }
    }
    i++;
  }
  return out;
}

/* ─────────────────────────────────────────────────────────────
 * Pipeline stages 2-4: normalize (done in extract) | group_by(hash) |
 * filter(count>1 across ≥2 files) → report
 * ───────────────────────────────────────────────────────────── */
std::vector<DupFinding> find_duplicate_symbols(const std::vector<Symbol>& symbols) {
  // Group by (kind, body_hash, norm_body). norm_body guards against hash
  // collisions — two entries only merge if bodies are byte-identical.
  struct Key {
    SymbolKind kind;
    std::size_t hash;
    std::string body;
    bool operator<(const Key& o) const {
      if (kind != o.kind) return kind < o.kind;
      if (hash != o.hash) return hash < o.hash;
      return body < o.body;
    }
  };

  std::map<Key, std::vector<const Symbol*>> groups;
  for (const auto& s : symbols) groups[{s.kind, s.body_hash, s.norm_body}].push_back(&s);

  std::vector<DupFinding> findings;
  for (const auto& [key, members] : groups) {
    if (members.size() < 2) continue;  // filter: not a duplicate

    // Require the duplication to span ≥2 distinct files (real copy-paste).
    std::set<std::string> files;
    for (auto* m : members) files.insert(m->file);
    if (files.size() < 2) continue;

    DupFinding f;
    f.type = key.kind == SymbolKind::Function ? "duplicate-function" : "duplicate-file-variable";
    f.severity = "warning";
    f.name = members.front()->name;
    for (auto* m : members) f.locations.push_back(m->file + ":" + std::to_string(m->line));

    std::string locs;
    for (size_t i = 0; i < f.locations.size(); i++) {
      if (i) locs += ", ";
      locs += f.locations[i];
    }
    f.message = "Duplicate " + std::string(key.kind == SymbolKind::Function ? "function" : "file variable") +
                " '" + f.name + "' with identical body in " + std::to_string(members.size()) +
                " places: " + locs;
    f.fix = "Extract the shared definition into a single header/module and include it, "
            "instead of copy-pasting it across files.";
    findings.push_back(std::move(f));
  }

  // Stable order for deterministic output/tests.
  std::sort(findings.begin(), findings.end(),
            [](const DupFinding& a, const DupFinding& b) { return a.name < b.name; });
  return findings;
}

/* ── Full pipeline over a directory ── */
std::vector<DupFinding> analyze_duplicate_symbols(const std::string& root) {
  std::vector<std::string> files;
  find_source_files(root, files);

  std::vector<Symbol> all;
  for (const auto& abs : files) {
    std::string rel = make_relative(abs, root);
    std::string content = read_file(abs);
    if (content.empty()) continue;
    auto syms = extract_symbols(content, get_extension(abs), rel);
    all.insert(all.end(), syms.begin(), syms.end());
  }
  return find_duplicate_symbols(all);
}
