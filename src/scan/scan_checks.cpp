/**
 * @file scan_checks.cpp
 * @brief Repo quality checks — thin dispatcher.
 *
 * Delegates to focused modules:
 *   scan_classify  — repo type + monorepo detection
 *   scan_lang      — language-specific checks (function pointer map)
 *   scan_ci        — CI/CD pipeline checks
 *   scan_universal — docs, standards, testing, git health, secrets
 *
 * @see ADR-139 (scan architecture), docs/designs/refactoring-plan.md
 */
#include "scan_checks.h"

#include <cstdio>

#include "scan.h"

FILE* g_findings_file = nullptr;

void finding_write(const char* repo, const char* check, const char* severity, const char* file, const char* rule, const char* message) {
  if (!g_findings_file) return;
  fprintf(g_findings_file,
          "{\"repo\":\"%s\",\"check\":\"%s\",\"severity\":\"%s\","
          "\"file\":\"%s\",\"rule\":\"%s\",\"message\":\"%s\"}\n",
          repo, check, severity, file, rule, message);
}

int run_repo_checks(Repo& repo, const ScanOptions& /*opts*/) {
  int total = 0;
  total += scan_classify(repo);
  total += scan_universal(repo);
  total += scan_lang(repo);
  total += scan_ci(repo);
  return total;
}
