/**
 * @file rule_engine.h
 * @brief Pluggable rule engine — loads .rule files, evaluates patterns.
 * @see ADR-145
 *
 * Zero external dependencies beyond RE2 (Google's regex library).
 * Rules are simple key:value files, trivial to parse.
 */
#ifndef CPM_RULE_ENGINE_H
#define CPM_RULE_ENGINE_H

#include <re2/re2.h>
#include <re2/set.h>

#include <memory>
#include <string>
#include <vector>

/** @brief A single pattern within a rule. */
struct RulePattern {
  std::string regex_str;
  std::string message;
  int set_index = -1;  // index in RE2::Set (assigned at compile time)
};

/** @brief Target specification: which files to scan. */
struct RuleTarget {
  std::vector<std::string> extensions;     // e.g. {".ts", ".js", ".py"}
  std::vector<std::string> filenames;      // e.g. {"Dockerfile", "Makefile"}
  std::vector<std::string> exclude_paths;  // e.g. {"test/", "vendor/"}
  std::string content_contains;            // fast pre-filter (literal match)
  int scope_start = 0;                     // ADR-166: 1-indexed start line (0 = no scope)
  int scope_end = 0;                       // ADR-166: 1-indexed end line (0 = no scope)
};

/** @brief A complete rule loaded from a .rule file. */
struct Rule {
  std::string id;
  std::string title;
  std::string category;
  std::string severity;  // "error", "warning", "info"
  std::string engine;    // "pattern", "absence", "presence", "file-absence", "file-presence", "extract-duplicates" (ADR-166)
  std::string fix;
  bool skip_comments = false;  // strip comments before matching (ADR-165)
  bool skip_strings = false;   // strip string literals before matching (ADR-165)
  RuleTarget target;
  std::vector<RulePattern> patterns;
  std::string extract_regex;   // ADR-166 phase 5: regex for value extraction
  int extract_capture = 1;     // ADR-166 phase 5: capture group index (1-based)
  std::string extract_message; // ADR-166 phase 5: message template ('{match}' replaced)
  // Function-name allowlist for callee-style pattern rules: if the matched
  // line also contains a call to one of these names, the finding is suppressed.
  // Lets a pattern rule exclude idiomatic cheap calls (e.g. i18n t()/$t())
  // without brittle negative-lookahead regex (RE2 has no lookaround).
  // block-absence engine: the first pattern is the block-START regex (e.g.
  // `\b(it|test)\s*\(`); `block_inner` is the regex that MUST appear somewhere
  // inside that block's balanced braces (e.g. `\bexpect\s*\(`). A block whose
  // braces contain no `block_inner` match is reported. Needs no full parser —
  // block bounds are found by counting `{`/`}` (after optional string/comment
  // stripping) from the start line.
  //
  // `block_trigger` (optional) gates the rule: the block is only evaluated when
  // this regex appears somewhere inside it. This turns block-absence into a
  // general "scope contains A but not B" check — e.g. START=`func .*{`,
  // trigger=`os\.(Open|Create)\(`, inner=`\.Close\(|defer ` flags a function
  // that opens a file but never closes it (resource leak). When empty, every
  // matched block is evaluated (original behaviour — backward compatible).
  std::string block_inner;
  std::string block_trigger;
  std::vector<std::string> exclude_names;
};

/** @brief A finding produced by the rule engine. */
struct RuleFinding {
  std::string rule_id;
  std::string severity;
  std::string file;
  int line = 0;
  std::string message;
  std::string fix;
};

/**
 * @brief Load all .rule files from a directory (recursively).
 */
std::vector<Rule> rules_load(const std::string& dir);

/**
 * @brief Parse a single .rule file.
 */
Rule rule_parse(const std::string& path);

/**
 * @brief Run all rules against a project directory (single-pass, RE2-powered).
 */
std::vector<RuleFinding> rules_scan(const std::vector<Rule>& rules, const std::string& root);

/**
 * @brief Check if a file matches a rule's target specification.
 */
bool rule_matches_file(const Rule& rule, const std::string& rel_path);

#endif
