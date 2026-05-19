/**
// @see ADR-129
 * @file junit.h
 * @brief JUnit XML builder — object model that serializes to spec-compliant XML.
 *
 * Usage:
 *   JUnit report("cpm-check");
 *   auto& suite = report.add_suite("secrets-fast");
 *   suite.add_pass("clean-file", "src/ok.cpp", 0, 0.001);
 *   suite.add_failure("hardcoded-secret", "src/main.cpp", 42, 0.003,
 *       "API key detected", "Use env var", "https://cpm.dev/checks/secrets");
 *   report.write(stdout);
 */
#ifndef CPM_REPORT_JUNIT_H
#define CPM_REPORT_JUNIT_H

#include <cstdio>
#include <string>
#include <vector>

#include "../checks/check.h"

struct JUnitProperty {
  std::string name;
  std::string value;
};

struct JUnitTestCase {
  std::string name;
  std::string classname;
  std::string file;
  int line = 0;
  double time = 0;
  std::string status; /* "passed" | "failure" | "warning" | "skipped" */
  std::string message;
  std::string fix;
  std::string docs;
  std::vector<JUnitProperty> properties;
};

struct JUnitTestSuite {
  std::string name;
  std::vector<JUnitTestCase> cases;

  JUnitTestCase& add_pass(const std::string& name, const std::string& file, int line, double time);
  JUnitTestCase& add_failure(const std::string& name, const std::string& file, int line, double time, const std::string& message,
                             const std::string& fix = "", const std::string& docs = "");
  JUnitTestCase& add_warning(const std::string& name, const std::string& file, int line, double time, const std::string& message,
                             const std::string& fix = "", const std::string& docs = "");
  JUnitTestCase& add_skipped(const std::string& name, const std::string& message = "");

  int tests() const { return (int)cases.size(); }
  int failures() const;
  double total_time() const;
};

struct JUnit {
  std::string name;
  std::vector<JUnitTestSuite> suites;

  JUnit(const std::string& name) : name(name) {}

  JUnitTestSuite& add_suite(const std::string& name);

  /** @brief Build from findings (groups by check). */
  static JUnit from_findings(const std::vector<Finding>& findings, const std::string& name);

  /** @brief Serialize to FILE (stdout or file). */
  void write(FILE* out) const;

  /** @brief Convenience: write to file path. */
  void write_file(const std::string& path) const;

  int total_tests() const;
  int total_failures() const;
  double total_time() const;
};

#endif
