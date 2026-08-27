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
};

/** @brief A complete rule loaded from a .rule file. */
struct Rule {
  std::string id;
  std::string title;
  std::string category;
  std::string severity;  // "error", "warning", "info"
  std::string engine;    // "pattern", "absence", "presence"
  std::string fix;
  bool skip_comments = false;  // strip comments before matching (ADR-165)
  bool skip_strings = false;   // strip string literals before matching (ADR-165)
  RuleTarget target;
  std::vector<RulePattern> patterns;
};

/** @brief A finding produced by the rule engine. */
struct RuleFinding {
  std::string rule_id;
  std::string severity;
  std::string file;
  int line;
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
