/**
 * @file cmd_rule_scan.cpp
 * @brief `cpm rule-scan` — run pluggable rules against a project.
 * @see ADR-145
 *
 * Standalone entry point for PoC. Will be integrated into main.cpp later.
 * Build: g++ -std=c++17 -O2 -o build/rule-scan src/rules/cmd_rule_scan.cpp src/rules/rule_engine.cpp -lre2
 */
#include <chrono>
#include <cstdio>
#include <cstring>

#include "rule_engine.h"

// ANSI colors
#define RED "\033[31m"
#define YEL "\033[33m"
#define BLU "\033[34m"
#define GRN "\033[32m"
#define DIM "\033[2m"
#define RST "\033[0m"

static const char* severity_color(const std::string& sev) {
  if (sev == "error") return RED;
  if (sev == "warning") return YEL;
  return BLU;
}

/**
 * @brief Escape a string for safe embedding in a JSON value.
 *
 * Encodes double quotes, backslashes, and common control characters
 * so the output is valid JSON regardless of rule message content.
 */
static std::string json_escape(const std::string& s) {
  std::string out;
  out.reserve(s.size());
  for (char c : s) {
    switch (c) {
      case '"':
        out += "\\\"";
        break;
      case '\\':
        out += "\\\\";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        out += c;
        break;
    }
  }
  return out;
}

int main(int argc, char** argv) {
  std::string root = ".";
  std::string rules_dir = "rules";
  bool json_output = false;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--json") == 0)
      json_output = true;
    else if (strcmp(argv[i], "--rules") == 0 && i + 1 < argc)
      rules_dir = argv[++i];
    else if (argv[i][0] != '-')
      root = argv[i];
  }

  // Load rules
  auto t0 = std::chrono::high_resolution_clock::now();
  auto rules = rules_load(rules_dir);
  auto t1 = std::chrono::high_resolution_clock::now();

  if (rules.empty()) {
    fprintf(stderr, "  No rules found in %s/\n", rules_dir.c_str());
    return 1;
  }

  // Count patterns
  int total_patterns = 0;
  for (auto& r : rules) total_patterns += (int)r.patterns.size();

  // Scan
  auto findings = rules_scan(rules, root);
  auto t2 = std::chrono::high_resolution_clock::now();

  double load_ms = std::chrono::duration<double, std::milli>(t1 - t0).count();
  double scan_ms = std::chrono::duration<double, std::milli>(t2 - t1).count();

  if (json_output) {
    // JSONL output — escape all string fields to ensure valid JSON
    for (auto& f : findings) {
      printf("{\"rule\":\"%s\",\"severity\":\"%s\",\"file\":\"%s\",\"line\":%d,\"message\":\"%s\"}\n", json_escape(f.rule_id).c_str(),
             json_escape(f.severity).c_str(), json_escape(f.file).c_str(), f.line, json_escape(f.message).c_str());
    }
    // Only non-zero on errors (same semantics as terminal mode)
    for (auto& f : findings) {
      if (f.severity == "error") return 1;
    }
    return 0;
  }

  // Terminal output
  printf("\n  " GRN "cpm rule-scan" RST " — %zu rules, %d patterns\n", rules.size(), total_patterns);
  printf("  ─────────────────────────────────────────\n");

  if (findings.empty()) {
    printf("  " GRN "✓ No findings" RST "\n");
  } else {
    // Group by file
    std::string last_file;
    int errors = 0, warnings = 0, infos = 0;

    for (auto& f : findings) {
      if (f.file != last_file) {
        if (!last_file.empty()) printf("\n");
        printf("  " DIM "%s" RST "\n", f.file.c_str());
        last_file = f.file;
      }
      printf("    %s%-7s" RST "  L%-4d  [%s] %s\n", severity_color(f.severity), f.severity.c_str(), f.line, f.rule_id.c_str(),
             f.message.c_str());

      if (f.severity == "error")
        errors++;
      else if (f.severity == "warning")
        warnings++;
      else
        infos++;
    }

    printf("\n  ─────────────────────────────────────────\n");
    printf("  ");
    if (errors) printf(RED "%d errors" RST "  ", errors);
    if (warnings) printf(YEL "%d warnings" RST "  ", warnings);
    if (infos) printf(BLU "%d info" RST "  ", infos);
    printf("\n");
  }

  // Performance stats
  printf("\n  " DIM "Rules loaded in %.1fms, scan completed in %.1fms" RST "\n", load_ms, scan_ms);
  printf("  " DIM "(%zu rules × project files = single-pass scan)" RST "\n\n", rules.size());

  // Exit with error if errors found
  int has_errors = 0;
  for (auto& f : findings) {
    if (f.severity == "error") {
      has_errors = 1;
      break;
    }
  }
  return has_errors;
}
