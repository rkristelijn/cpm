/**
 * @file rules_test.cpp
 * @brief Unit tests for rule engine (parsing, pattern, absence, presence, unsupported engines).
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "rules/rule_engine.h"

#include <sys/stat.h>
#include <unistd.h>

#include <cstdlib>
#include <fstream>

#include "../vendor/doctest.h"

static std::string create_temp_dir() {
  char template_path[] = "/tmp/cpm_rules_test_XXXXXX";
  char* dir = mkdtemp(template_path);
  return dir ? std::string(dir) : "";
}

static void write_file(const std::string& path, const std::string& content) {
  std::ofstream out(path);
  out << content;
}

TEST_CASE("rule_parse parses engine correctly") {
  std::string tmp_dir = create_temp_dir();
  REQUIRE(!tmp_dir.empty());

  std::string rule_path = tmp_dir + "/test.rule";
  write_file(rule_path,
             "id: TEST-001\n"
             "title: Test Rule\n"
             "engine: absence\n"
             "severity: error\n"
             "extensions: .txt\n"
             "patterns:\n"
             "  - regex: required_header\n"
             "    message: Missing required header\n");

  Rule rule = rule_parse(rule_path);
  CHECK(rule.id == "TEST-001");
  CHECK(rule.engine == "absence");
  CHECK(rule.severity == "error");
  CHECK(rule.patterns.size() == 1);
  CHECK(rule.patterns[0].regex_str == "required_header");

  unlink(rule_path.c_str());
  rmdir(tmp_dir.c_str());
}

TEST_CASE("rules_scan with pattern engine") {
  std::string tmp_dir = create_temp_dir();
  REQUIRE(!tmp_dir.empty());

  std::string file_path = tmp_dir + "/sample.txt";
  write_file(file_path, "line 1: ok\nline 2: BAD_PATTERN\nline 3: BAD_PATTERN\n");

  Rule rule;
  rule.id = "PAT-001";
  rule.severity = "warning";
  rule.engine = "pattern";
  rule.target.extensions = {".txt"};
  rule.patterns.push_back({"BAD_PATTERN", "Found bad pattern"});

  auto findings = rules_scan({rule}, tmp_dir);
  CHECK(findings.size() == 2);
  if (findings.size() == 2) {
    CHECK(findings[0].line == 2);
    CHECK(findings[0].rule_id == "PAT-001");
    CHECK(findings[1].line == 3);
  }

  unlink(file_path.c_str());
  rmdir(tmp_dir.c_str());
}

TEST_CASE("rules_scan with absence engine") {
  std::string tmp_dir = create_temp_dir();
  REQUIRE(!tmp_dir.empty());

  std::string file1 = tmp_dir + "/has_header.txt";
  std::string file2 = tmp_dir + "/no_header.txt";

  write_file(file1, "HEADER_LICENSE_2026\nsome content\n");
  write_file(file2, "some content without header\n");

  Rule rule;
  rule.id = "ABS-001";
  rule.severity = "error";
  rule.engine = "absence";
  rule.target.extensions = {".txt"};
  rule.patterns.push_back({"HEADER_LICENSE", "Missing license header"});

  auto findings = rules_scan({rule}, tmp_dir);
  // file1 has the header -> no finding. file2 misses header -> 1 finding.
  CHECK(findings.size() == 1);
  if (findings.size() == 1) {
    CHECK(findings[0].file == "no_header.txt");
    CHECK(findings[0].line == 1);
    CHECK(findings[0].rule_id == "ABS-001");
  }

  unlink(file1.c_str());
  unlink(file2.c_str());
  rmdir(tmp_dir.c_str());
}

TEST_CASE("rules_scan with presence engine") {
  std::string tmp_dir = create_temp_dir();
  REQUIRE(!tmp_dir.empty());

  std::string file_path = tmp_dir + "/multi_match.txt";
  write_file(file_path, "line 1: clean\nline 2: FORBIDDEN\nline 3: FORBIDDEN\n");

  Rule rule;
  rule.id = "PRES-001";
  rule.severity = "warning";
  rule.engine = "presence";
  rule.target.extensions = {".txt"};
  rule.patterns.push_back({"FORBIDDEN", "Forbidden construct present"});

  auto findings = rules_scan({rule}, tmp_dir);
  // Presence engine should report at most 1 finding per file (at first matching line)
  CHECK(findings.size() == 1);
  if (findings.size() == 1) {
    CHECK(findings[0].line == 2);
    CHECK(findings[0].rule_id == "PRES-001");
  }

  unlink(file_path.c_str());
  rmdir(tmp_dir.c_str());
}

TEST_CASE("rules_scan handles unsupported engine gracefully") {
  std::string tmp_dir = create_temp_dir();
  REQUIRE(!tmp_dir.empty());

  std::string file_path = tmp_dir + "/sample.txt";
  write_file(file_path, "line 1: BAD_PATTERN\n");

  Rule rule;
  rule.id = "UNSUP-001";
  rule.severity = "info";
  rule.engine = "unsupported_metric_engine";
  rule.target.extensions = {".txt"};
  rule.patterns.push_back({"BAD_PATTERN", "Should not trigger"});

  auto findings = rules_scan({rule}, tmp_dir);
  // Unsupported engine should not evaluate pattern matching, so 0 findings
  CHECK(findings.empty());

  unlink(file_path.c_str());
  rmdir(tmp_dir.c_str());
}

TEST_CASE("rules_scan handles invalid regex gracefully") {
  std::string tmp_dir = create_temp_dir();
  REQUIRE(!tmp_dir.empty());

  std::string file_path = tmp_dir + "/sample.txt";
  write_file(file_path, "line 1: BAD_PATTERN\n");

  Rule rule;
  rule.id = "BADREG-001";
  rule.severity = "warning";
  rule.engine = "pattern";
  rule.target.extensions = {".txt"};
  rule.patterns.push_back({"[invalid(regex", "Bad regex"});

  auto findings = rules_scan({rule}, tmp_dir);
  // Invalid regex fails compilation, emits warning diagnostic to stderr, and yields 0 findings
  CHECK(findings.empty());

  unlink(file_path.c_str());
  rmdir(tmp_dir.c_str());
}

TEST_CASE("rules_scan skips oversized files") {
  std::string tmp_dir = create_temp_dir();
  REQUIRE(!tmp_dir.empty());

  std::string file_path = tmp_dir + "/large.txt";
  // Create a file >= 1MB (1024 * 1024 + 1 bytes)
  std::ofstream out(file_path, std::ios::binary);
  std::string chunk(1024, 'a');
  for (int i = 0; i < 1025; i++) {
    out << chunk;
  }
  out.close();

  Rule rule;
  rule.id = "LARGE-001";
  rule.severity = "warning";
  rule.engine = "pattern";
  rule.target.extensions = {".txt"};
  rule.patterns.push_back({"a", "Match a"});

  auto findings = rules_scan({rule}, tmp_dir);
  // File >= 1MB is skipped with stderr diagnostic, yielding 0 findings
  CHECK(findings.empty());

  unlink(file_path.c_str());
  rmdir(tmp_dir.c_str());
}
