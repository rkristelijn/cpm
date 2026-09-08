/**
 * @file import_graph.cpp
 * @brief Import graph implementation — multi-language extraction + graph analysis.
 *
 * Uses std::regex for import pattern matching (zero external deps).
 * Uses Tarjan's SCC for O(V+E) cycle detection.
 *
 * @see import_graph.h for public API
 */
#include "import_graph.h"

#include <dirent.h>
#include <sys/stat.h>

#include <algorithm>
#include <cstring>
#include <fstream>
#include <functional>
#include <regex>
#include <set>
#include <stack>
#include <unordered_set>

/* ── Thresholds ─────────────────────────────────────────────── */

static constexpr int FAN_OUT_THRESHOLD = 15;
static constexpr int FAN_IN_THRESHOLD = 20;

/* ── File extension sets ────────────────────────────────────── */

static const std::unordered_set<std::string> SOURCE_EXTENSIONS = {
    ".ts",   ".tsx", ".js",  ".jsx", ".mjs", ".cjs",  // JS/TS
    ".py",                                            // Python
    ".go",                                            // Go
    ".java",                                          // Java
    ".cpp",  ".cc",  ".cxx", ".c",   ".h",   ".hpp",  // C/C++
    ".cs",                                            // C#
    ".php",                                           // PHP
    ".rb",                                            // Ruby
    ".rs",                                            // Rust
};

/* ── Directories to skip (mirrors scan.cpp) ─────────────────── */

static bool should_skip_dir(const char* name) {
  return std::strcmp(name, "node_modules") == 0 || std::strcmp(name, ".git") == 0 || std::strcmp(name, "build") == 0 ||
         std::strcmp(name, "dist") == 0 || std::strcmp(name, "target") == 0 || std::strcmp(name, ".cache") == 0 ||
         std::strcmp(name, "vendor") == 0 || std::strcmp(name, ".tmp") == 0 || std::strcmp(name, "out") == 0 ||
         std::strcmp(name, ".next") == 0 || std::strcmp(name, "coverage") == 0 || std::strcmp(name, "__pycache__") == 0;
}

/* ── Helper: get file extension ─────────────────────────────── */

static std::string get_extension(const std::string& path) {
  auto dot = path.rfind('.');
  if (dot == std::string::npos) return "";
  return path.substr(dot);
}

/* ── Helper: read file content ──────────────────────────────── */

static std::string read_file(const std::string& path) {
  FILE* f = std::fopen(path.c_str(), "r");
  if (!f) return "";
  std::string content;
  char buf[4096];
  size_t n;
  while ((n = std::fread(buf, 1, sizeof(buf), f)) > 0) content.append(buf, n);
  std::fclose(f);
  return content;
}

/* ── Helper: recursive file discovery ───────────────────────── */

static void find_source_files(const std::string& dir, std::vector<std::string>& out) {
  DIR* d = opendir(dir.c_str());
  if (!d) return;
  struct dirent* entry;
  while ((entry = readdir(d)) != nullptr) {
    if (entry->d_name[0] == '.') continue;
    std::string full = dir + "/" + entry->d_name;
    struct stat st;
    if (stat(full.c_str(), &st) != 0) continue;
    if (S_ISDIR(st.st_mode)) {
      if (!should_skip_dir(entry->d_name)) find_source_files(full, out);
    } else if (S_ISREG(st.st_mode)) {
      std::string ext = get_extension(entry->d_name);
      if (SOURCE_EXTENSIONS.count(ext)) out.push_back(full);
    }
  }
  closedir(d);
}

/* ── Helper: make path relative to root ─────────────────────── */

static std::string make_relative(const std::string& path, const std::string& root) {
  if (path.size() > root.size() && path.substr(0, root.size()) == root) {
    size_t start = root.size();
    if (start < path.size() && path[start] == '/') ++start;
    return path.substr(start);
  }
  return path;
}

/* ═══════════════════════════════════════════════════════════════
 * Import extraction — one function per language family
 * ═══════════════════════════════════════════════════════════════ */

/** @brief JS/TS: import from '...', require('...'), import('...') */
static std::vector<std::string> extract_js_imports(const std::string& content) {
  std::vector<std::string> imports;
  /* import ... from 'module' */
  std::regex re_from(R"((?:import|export)\s+.*?\s+from\s+['"]([^'"]+)['"])");
  /* require('module') */
  std::regex re_require(R"(require\s*\(\s*['"]([^'"]+)['"]\s*\))");
  /* import('module') — dynamic */
  std::regex re_dynamic(R"(import\s*\(\s*['"]([^'"]+)['"]\s*\))");

  for (auto* re : {&re_from, &re_require, &re_dynamic}) {
    auto begin = std::sregex_iterator(content.begin(), content.end(), *re);
    auto end = std::sregex_iterator();
    for (auto it = begin; it != end; ++it) {
      imports.push_back((*it)[1].str());
    }
  }
  return imports;
}

/** @brief Python: from X import Y, import X */
static std::vector<std::string> extract_python_imports(const std::string& content) {
  std::vector<std::string> imports;
  /* from module import ... */
  std::regex re_from(R"(^\s*from\s+(\S+)\s+import\b)", std::regex::multiline);
  /* import module (handles "import a, b, c") */
  std::regex re_import(R"(^\s*import\s+(\S+))", std::regex::multiline);

  auto begin = std::sregex_iterator(content.begin(), content.end(), re_from);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) imports.push_back((*it)[1].str());

  begin = std::sregex_iterator(content.begin(), content.end(), re_import);
  for (auto it = begin; it != end; ++it) {
    std::string mod = (*it)[1].str();
    /* Strip trailing comma for "import a, b" — take first module */
    auto comma = mod.find(',');
    if (comma != std::string::npos) mod = mod.substr(0, comma);
    imports.push_back(mod);
  }
  return imports;
}

/** @brief Go: import "pkg" and import (\n"pkg"\n) */
static std::vector<std::string> extract_go_imports(const std::string& content) {
  std::vector<std::string> imports;
  /* Single import: import "pkg" */
  std::regex re_single(R"~~(^\s*import\s+"([^"]+)")~~", std::regex::multiline);
  /* Block import: all quoted strings inside import (...) */
  std::regex re_block(R"~~(import\s*\(([\s\S]*?)\))~~");
  std::regex re_quoted(R"~~("([^"]+)")~~");

  /* Single imports */
  auto it_begin = std::sregex_iterator(content.begin(), content.end(), re_single);
  auto it_end = std::sregex_iterator();
  for (auto it = it_begin; it != it_end; ++it) imports.push_back((*it)[1].str());

  /* Block imports */
  auto block_begin = std::sregex_iterator(content.begin(), content.end(), re_block);
  for (auto bit = block_begin; bit != it_end; ++bit) {
    std::string block = (*bit)[1].str();
    auto qbegin = std::sregex_iterator(block.begin(), block.end(), re_quoted);
    for (auto qit = qbegin; qit != it_end; ++qit) imports.push_back((*qit)[1].str());
  }
  return imports;
}

/** @brief Java: import x.y.z; */
static std::vector<std::string> extract_java_imports(const std::string& content) {
  std::vector<std::string> imports;
  std::regex re(R"(^\s*import\s+([\w.]+)\s*;)", std::regex::multiline);
  auto begin = std::sregex_iterator(content.begin(), content.end(), re);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) imports.push_back((*it)[1].str());
  return imports;
}

/** @brief C/C++: #include "..." (user includes only, not <system>) */
static std::vector<std::string> extract_cpp_imports(const std::string& content) {
  std::vector<std::string> imports;
  std::regex re(R"~~(^\s*#\s*include\s+"([^"]+)")~~", std::regex::multiline);
  auto it_begin = std::sregex_iterator(content.begin(), content.end(), re);
  auto it_end = std::sregex_iterator();
  for (auto it = it_begin; it != it_end; ++it) imports.push_back((*it)[1].str());
  return imports;
}

/** @brief C#: using X.Y; */
static std::vector<std::string> extract_csharp_imports(const std::string& content) {
  std::vector<std::string> imports;
  std::regex re(R"(^\s*using\s+([\w.]+)\s*;)", std::regex::multiline);
  auto begin = std::sregex_iterator(content.begin(), content.end(), re);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) imports.push_back((*it)[1].str());
  return imports;
}

/** @brief PHP: use X\Y;, require_once '...' */
static std::vector<std::string> extract_php_imports(const std::string& content) {
  std::vector<std::string> imports;
  /* use Namespace\Class; */
  std::regex re_use(R"(^\s*use\s+([\w\\]+)\s*;)", std::regex::multiline);
  /* require_once/include_once/require/include '...' */
  std::regex re_require(R"((require_once|include_once|require|include)\s+['"]([^'"]+)['"])");

  auto begin = std::sregex_iterator(content.begin(), content.end(), re_use);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) imports.push_back((*it)[1].str());

  begin = std::sregex_iterator(content.begin(), content.end(), re_require);
  for (auto it = begin; it != end; ++it) imports.push_back((*it)[2].str());
  return imports;
}

/** @brief Ruby: require '...', require_relative '...' */
static std::vector<std::string> extract_ruby_imports(const std::string& content) {
  std::vector<std::string> imports;
  std::regex re(R"((require_relative|require)\s+['"]([^'"]+)['"])");
  auto begin = std::sregex_iterator(content.begin(), content.end(), re);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) imports.push_back((*it)[2].str());
  return imports;
}

/** @brief Rust: use crate::..., mod ...; */
static std::vector<std::string> extract_rust_imports(const std::string& content) {
  std::vector<std::string> imports;
  /* use crate::module::item; */
  std::regex re_use(R"(^\s*use\s+(crate::\S+)\s*;)", std::regex::multiline);
  /* mod name; (external module declaration) */
  std::regex re_mod(R"(^\s*mod\s+(\w+)\s*;)", std::regex::multiline);

  auto begin = std::sregex_iterator(content.begin(), content.end(), re_use);
  auto end = std::sregex_iterator();
  for (auto it = begin; it != end; ++it) imports.push_back((*it)[1].str());

  begin = std::sregex_iterator(content.begin(), content.end(), re_mod);
  for (auto it = begin; it != end; ++it) imports.push_back((*it)[1].str());
  return imports;
}

/* ═══════════════════════════════════════════════════════════════
 * Public API: extract_imports
 * ═══════════════════════════════════════════════════════════════ */

std::vector<std::string> extract_imports(const std::string& content, const std::string& extension) {
  if (extension == ".ts" || extension == ".tsx" || extension == ".js" || extension == ".jsx" || extension == ".mjs" || extension == ".cjs")
    return extract_js_imports(content);
  if (extension == ".py") return extract_python_imports(content);
  if (extension == ".go") return extract_go_imports(content);
  if (extension == ".java") return extract_java_imports(content);
  if (extension == ".cpp" || extension == ".cc" || extension == ".cxx" || extension == ".c" || extension == ".h" || extension == ".hpp")
    return extract_cpp_imports(content);
  if (extension == ".cs") return extract_csharp_imports(content);
  if (extension == ".php") return extract_php_imports(content);
  if (extension == ".rb") return extract_ruby_imports(content);
  if (extension == ".rs") return extract_rust_imports(content);
  return {};
}

/* ── Helper: resolve an import string to a known file ────────── */

/**
 * @brief Try to resolve an import target to a known file in the graph.
 *
 * Tries several strategies:
 * 1. Direct match (e.g. "my_header.h" exists as-is)
 * 2. Relative path resolution from importing file's directory
 * 3. Stem matching with common extensions
 */
static std::string resolve_import(const std::string& raw_import, const std::string& from_file,
                                  const std::unordered_set<std::string>& known) {
  /* 1. Direct match */
  if (known.count(raw_import)) return raw_import;

  /* Get directory of the importing file */
  std::string dir;
  auto slash = from_file.rfind('/');
  if (slash != std::string::npos) dir = from_file.substr(0, slash);

  /* 2. Relative path resolution (strip leading ./) */
  std::string rel = raw_import;
  if (rel.size() > 2 && rel[0] == '.' && rel[1] == '/') rel = rel.substr(2);
  if (rel.size() > 3 && rel[0] == '.' && rel[1] == '.' && rel[2] == '/') {
    /* Go up one directory */
    if (!dir.empty()) {
      auto parent_slash = dir.rfind('/');
      std::string parent = (parent_slash != std::string::npos) ? dir.substr(0, parent_slash) : "";
      rel = parent.empty() ? rel.substr(3) : parent + "/" + rel.substr(3);
    }
  } else if (!dir.empty() && rel[0] != '/') {
    /* Prepend directory of importing file for relative imports */
    if (raw_import[0] == '.') rel = dir + "/" + rel;
  }

  /* Try direct relative path */
  if (known.count(rel)) return rel;

  /* 3. Try common extensions */
  static const char* exts[] = {".ts",  ".tsx", ".js",  ".jsx", ".py", ".go", ".java", ".cpp", ".h",
                               ".hpp", ".cs",  ".php", ".rb",  ".rs", ".cc", ".cxx",  ".c",   ".mjs"};
  for (auto ext : exts) {
    std::string candidate = rel + ext;
    if (known.count(candidate)) return candidate;
  }

  /* Try /index variants */
  static const char* index_files[] = {"/index.ts", "/index.js", "/index.tsx", "/index.jsx"};
  for (auto idx : index_files) {
    std::string candidate = rel + idx;
    if (known.count(candidate)) return candidate;
  }

  /* Unresolved — return empty */
  return "";
}

/* ═══════════════════════════════════════════════════════════════
 * Public API: build_import_graph
 * ═══════════════════════════════════════════════════════════════ */

ImportGraph build_import_graph(const std::string& root) {
  ImportGraph graph;

  /* Discover all source files */
  std::vector<std::string> abs_files;
  find_source_files(root, abs_files);

  /* Build set of known files (relative paths) for resolving imports */
  std::unordered_set<std::string> known;
  for (const auto& f : abs_files) {
    std::string rel = make_relative(f, root);
    graph.files.push_back(rel);
    known.insert(rel);
    graph.fan_in[rel] = 0;  // initialize
    graph.fan_out[rel] = 0;
  }

  /* Extract imports and build adjacency list */
  for (const auto& abs_path : abs_files) {
    std::string rel = make_relative(abs_path, root);
    std::string ext = get_extension(rel);
    std::string content = read_file(abs_path);
    auto imports = extract_imports(content, ext);

    std::vector<std::string>& edges = graph.adjacency[rel];
    for (const auto& imp : imports) {
      /* Try to resolve import to a known file */
      std::string resolved = resolve_import(imp, rel, known);
      if (!resolved.empty()) {
        edges.push_back(resolved);
        graph.fan_out[rel]++;
        graph.fan_in[resolved]++;
      } else {
        /* Unresolved import — still record the raw edge for fan_out */
        edges.push_back(imp);
        graph.fan_out[rel]++;
      }
    }
  }

  return graph;
}

/* ═══════════════════════════════════════════════════════════════
 * Tarjan's SCC — finds all strongly connected components
 * ═══════════════════════════════════════════════════════════════ */

namespace {

struct TarjanState {
  std::unordered_map<std::string, int> index_of;
  std::unordered_map<std::string, int> lowlink;
  std::unordered_map<std::string, bool> on_stack;
  std::stack<std::string> stack;
  int next_index = 0;
  std::vector<std::vector<std::string>> sccs;  // SCCs with size > 1 are cycles
};

static void tarjan_visit(const std::string& node, const std::unordered_map<std::string, std::vector<std::string>>& adj,
                         TarjanState& state) {
  state.index_of[node] = state.next_index;
  state.lowlink[node] = state.next_index;
  state.next_index++;
  state.stack.push(node);
  state.on_stack[node] = true;

  auto it = adj.find(node);
  if (it != adj.end()) {
    for (const auto& neighbor : it->second) {
      if (state.index_of.find(neighbor) == state.index_of.end()) {
        /* Neighbor not yet visited */
        tarjan_visit(neighbor, adj, state);
        state.lowlink[node] = std::min(state.lowlink[node], state.lowlink[neighbor]);
      } else if (state.on_stack[neighbor]) {
        /* Neighbor is on stack — part of current SCC */
        state.lowlink[node] = std::min(state.lowlink[node], state.index_of[neighbor]);
      }
    }
  }

  /* Root of an SCC */
  if (state.lowlink[node] == state.index_of[node]) {
    std::vector<std::string> scc;
    while (true) {
      std::string w = state.stack.top();
      state.stack.pop();
      state.on_stack[w] = false;
      scc.push_back(w);
      if (w == node) break;
    }
    if (scc.size() > 1) {
      std::sort(scc.begin(), scc.end());  // deterministic ordering
      state.sccs.push_back(std::move(scc));
    }
  }
}

}  // anonymous namespace

/* ═══════════════════════════════════════════════════════════════
 * Helper: entry point detection
 * ═══════════════════════════════════════════════════════════════ */

static bool is_entry_point(const std::string& file) {
  /* Common entry points that legitimately have zero fan-in */
  if (file.find("main") != std::string::npos) return true;
  if (file.find("index") != std::string::npos) return true;
  if (file.find("app") != std::string::npos) return true;
  if (file.find("test") != std::string::npos) return true;
  if (file.find("spec") != std::string::npos) return true;
  if (file.find("_test") != std::string::npos) return true;
  if (file.find("Test") != std::string::npos) return true;
  if (file.find("bench") != std::string::npos) return true;
  if (file.find("setup") != std::string::npos) return true;
  if (file.find("config") != std::string::npos) return true;
  if (file.find("Makefile") != std::string::npos) return true;
  if (file.find("CMakeLists") != std::string::npos) return true;
  return false;
}

/* ═══════════════════════════════════════════════════════════════
 * Public API: analyze_graph
 * ═══════════════════════════════════════════════════════════════ */

std::vector<GraphFinding> analyze_graph(const ImportGraph& graph) {
  std::vector<GraphFinding> findings;

  /* ── 1. Cycle detection via Tarjan's SCC ─────────────────── */
  TarjanState state;
  for (const auto& file : graph.files) {
    if (state.index_of.find(file) == state.index_of.end()) {
      tarjan_visit(file, graph.adjacency, state);
    }
  }
  for (const auto& scc : state.sccs) {
    std::string cycle_str;
    for (size_t i = 0; i < scc.size(); ++i) {
      if (i > 0) cycle_str += " → ";
      cycle_str += scc[i];
    }
    cycle_str += " → " + scc[0];  // close the cycle

    for (const auto& file : scc) {
      findings.push_back({"cycle", "error", file, "Circular dependency: " + cycle_str, "Extract shared code to a third module"});
    }
  }

  /* ── 2. Dead modules (fan_in == 0, not entry points) ─────── */
  for (const auto& file : graph.files) {
    auto it = graph.fan_in.find(file);
    int in_count = (it != graph.fan_in.end()) ? it->second : 0;
    if (in_count == 0 && !is_entry_point(file)) {
      findings.push_back(
          {"dead-module", "warning", file, "Module is never imported by any other file", "Remove if unused, or add to entry point"});
    }
  }

  /* ── 3. High fan-out (>15 imports — god module) ──────────── */
  for (const auto& [file, count] : graph.fan_out) {
    if (count > FAN_OUT_THRESHOLD) {
      findings.push_back({"high-fan-out", "warning", file,
                          "Imports " + std::to_string(count) + " modules (threshold: " + std::to_string(FAN_OUT_THRESHOLD) + ")",
                          "Split into smaller, focused modules"});
    }
  }

  /* ── 4. High fan-in (>20 importers — fragile dependency) ── */
  for (const auto& [file, count] : graph.fan_in) {
    if (count > FAN_IN_THRESHOLD) {
      findings.push_back({"high-fan-in", "info", file,
                          "Imported by " + std::to_string(count) + " files (threshold: " + std::to_string(FAN_IN_THRESHOLD) + ")",
                          "Consider if this module has too many responsibilities"});
    }
  }

  /* ── 5. Instability metric (informational) ───────────────── */
  for (const auto& file : graph.files) {
    auto in_it = graph.fan_in.find(file);
    auto out_it = graph.fan_out.find(file);
    int in_count = (in_it != graph.fan_in.end()) ? in_it->second : 0;
    int out_count = (out_it != graph.fan_out.end()) ? out_it->second : 0;
    int total = in_count + out_count;
    if (total > 0) {
      double instability = static_cast<double>(out_count) / total;
      /* Only report extreme instability (I > 0.9 with significant deps) */
      if (instability > 0.9 && out_count > 5) {
        findings.push_back({"high-instability", "info", file,
                            "Instability I=" + std::to_string(instability).substr(0, 4) + " (fan_in=" + std::to_string(in_count) +
                                ", fan_out=" + std::to_string(out_count) + ")",
                            "High instability means many outgoing deps — easy to change but fragile"});
      }
    }
  }

  return findings;
}
