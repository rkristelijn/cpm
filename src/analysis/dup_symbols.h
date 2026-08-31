/**
 * @file dup_symbols.h
 * @brief Generic duplicate-symbol detection — finds copy-pasted functions and
 *        file-scope variables across a codebase, language-agnostically.
 *
 * This is the C++ implementation of a conceptual Unix-style pipeline:
 *
 *   extract_symbols   (get-all-symbols)      — collect every function + file-var
 *     | normalize     (strip comments/ws)    — canonical body for comparison
 *     | group_by hash (sort | uniq)          — bucket identical bodies
 *     | filter count>1                        — keep only duplicates
 *     | report                                — emit findings
 *
 * Each stage is a separate function so that, once the rule engine grows
 * composable pipeline operators (ADR-166 follow-up), this logic can move
 * into a declarative .rule with no behavioural change.
 *
 * Detection is body-hash based, not name-based: two symbols are duplicates
 * only if their normalized bodies are byte-identical. This avoids false
 * positives from overloads, `main`, or unrelated same-named statics.
 *
 * Zero external dependencies. Reuses the tokenizer to strip comments/strings.
 *
 * @see ADR-170 (motivating case: strcasestr copy-pasted across scan files)
 * @see ADR-166 (rule engine — future home of this as a pipeline)
 */
#ifndef CPM_ANALYSIS_DUP_SYMBOLS_H
#define CPM_ANALYSIS_DUP_SYMBOLS_H

#include <string>
#include <vector>

/** @brief Kind of symbol extracted from source.
 *  Only Function is currently extracted; FileVariable is reserved for a
 *  future extractor (see docs/designs/duplicate-detection.md). */
enum class SymbolKind { Function, FileVariable };

/** @brief A single symbol definition found in a source file. */
struct Symbol {
  SymbolKind kind;
  std::string name;          // identifier (e.g. "strcasestr")
  std::string file;          // relative path where it was found
  int line;                  // 1-based line of the definition
  std::string norm_body;     // normalized body (comments/strings/whitespace collapsed)
  std::size_t body_hash;     // hash of norm_body, for fast grouping
};

/** @brief A finding: one group of duplicated symbols. */
struct DupFinding {
  std::string type;      // "duplicate-function" | "duplicate-file-variable"
  std::string severity;  // "warning"
  std::string name;      // the duplicated symbol name
  std::string message;   // human-readable summary listing all locations
  std::string fix;       // remediation advice
  std::vector<std::string> locations;  // "path:line" for each occurrence
};

// --- Pipeline stage 1: extract -------------------------------------------

/**
 * @brief Extract function definitions from one file (file-scope, brace-based).
 *
 * Currently extracts functions only (SymbolKind::Function). File-scope
 * variable extraction is planned but not yet implemented; see the design doc.
 * @param content   File content.
 * @param extension File extension including dot (e.g. ".cpp"). Unknown → empty.
 * @param file      Relative path (stored on each returned Symbol).
 * @return All symbols defined at file scope in this file.
 */
std::vector<Symbol> extract_symbols(const std::string& content, const std::string& extension,
                                    const std::string& file);

// --- Pipeline stages 2-4: normalize | group | filter ---------------------

/**
 * @brief Find groups of symbols with byte-identical normalized bodies.
 *
 * Groups the input symbols by (kind, body_hash), then keeps only groups that
 * span two or more distinct files (true copy-paste, not a single definition).
 *
 * @param symbols All symbols collected across the codebase.
 * @return One DupFinding per duplicated group.
 */
std::vector<DupFinding> find_duplicate_symbols(const std::vector<Symbol>& symbols);

// --- Convenience: full pipeline over a directory -------------------------

/**
 * @brief Run the whole pipeline over a project directory.
 *
 * Recursively scans source files, extracts symbols, and reports duplicates.
 *
 * @param root Project root directory.
 * @return Duplicate-symbol findings.
 */
std::vector<DupFinding> analyze_duplicate_symbols(const std::string& root);

#endif
