/**
 * @file import_graph.h
 * @brief Reusable import graph — multi-language dependency analysis.
 *
 * Generalizes circular.cpp and dead_code.cpp into a single graph that
 * both the check system and the rule engine can consume.
 *
 * Features:
 * - Multi-language import extraction via regex (9 languages)
 * - Tarjan's SCC for cycle detection (O(V+E))
 * - Dead module, fan-in, fan-out, instability analysis
 * - Zero external dependencies (std::regex only)
 *
 * @see ADR-013 (product positioning — architecture enforcement)
 */
#ifndef CPM_ANALYSIS_IMPORT_GRAPH_H
#define CPM_ANALYSIS_IMPORT_GRAPH_H

#include <string>
#include <unordered_map>
#include <vector>

/** @brief A single directed edge in the import graph. */
struct ImportEdge {
  std::string from_file;  // relative path
  std::string to_module;  // import target (may be relative path or module name)
};

/** @brief The complete import graph for a project directory. */
struct ImportGraph {
  std::vector<std::string> files;                                       // all source files
  std::unordered_map<std::string, std::vector<std::string>> adjacency;  // file -> [imported files]
  std::unordered_map<std::string, int> fan_in;                          // file -> number of importers
  std::unordered_map<std::string, int> fan_out;                         // file -> number of imports
};

/** @brief A finding produced by graph analysis. */
struct GraphFinding {
  std::string type;      // "cycle", "dead-module", "high-fan-out", "high-fan-in", "layer-violation"
  std::string severity;  // "error", "warning", "info"
  std::string file;
  std::string message;
  std::string fix;
};

/**
 * @brief Extract import targets from a single file's content.
 *
 * Supports: JS/TS, Python, Go, Java, C/C++, C#, PHP, Ruby, Rust.
 * Returns raw import strings (module names or paths, not resolved).
 *
 * @param content   File content to scan
 * @param extension File extension including dot (e.g. ".ts", ".py")
 * @return Vector of imported module/path strings
 */
std::vector<std::string> extract_imports(const std::string& content, const std::string& extension);

/**
 * @brief Build the full import graph from a project directory.
 *
 * Recursively finds source files, extracts imports, builds adjacency list.
 * Populates fan_in and fan_out counts.
 *
 * @param root Project root directory
 * @return Complete import graph
 */
ImportGraph build_import_graph(const std::string& root);

/**
 * @brief Run all graph analyses and return findings.
 *
 * Analyses performed:
 * 1. Cycle detection (Tarjan's SCC)
 * 2. Dead modules (fan_in == 0, excluding entry points)
 * 3. High fan-out (>15 imports — god module)
 * 4. High fan-in (>20 importers — fragile core dependency)
 * 5. Instability metric per file (informational)
 *
 * @param graph The import graph to analyze
 * @return Vector of findings
 */
std::vector<GraphFinding> analyze_graph(const ImportGraph& graph);

#endif
