/**
 * @file checks_test.cpp
 * @brief Unit tests for native checks — uses MockFileSystem, instant.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "../vendor/doctest.h"

#include "checks/check.h"
#include "io/mock_fs.h"
#include "runners/tool_runner.h"

/* Include check implementations */
#include "checks/secrets.cpp"
#include "checks/todo.cpp"
#include "checks/lockfile.cpp"

TEST_CASE("SecretsCheck detects API keys") {
  MockFileSystem fs;
  MockToolRunner runner;
  fs.add_file("src/main.cpp", "auto key = \"sk-12345678901234567890\";");

  SecretsCheck check;
  auto findings = check.run(fs, runner);
  CHECK(findings.size() == 1);
  CHECK(findings[0].rule == "hardcoded-secret");
  CHECK(findings[0].severity == "error");
  CHECK(findings[0].file == "src/main.cpp");
}

TEST_CASE("SecretsCheck detects AWS keys") {
  MockFileSystem fs;
  MockToolRunner runner;
  fs.add_file("src/config.ts", "const key = \"AKIAIOSFODNN7EXAMPLE\";");

  SecretsCheck check;
  auto findings = check.run(fs, runner);
  CHECK(findings.size() == 1);
  CHECK(findings[0].message.find("secret") != std::string::npos);
}

TEST_CASE("SecretsCheck ignores annotated lines") {
  MockFileSystem fs;
  MockToolRunner runner;
  fs.add_file("src/main.cpp", "// cpm:ignore secret\nauto key = \"sk-12345678901234567890\";");

  SecretsCheck check;
  auto findings = check.run(fs, runner);
  CHECK(findings.empty());
}

TEST_CASE("SecretsCheck clean file has no findings") {
  MockFileSystem fs;
  MockToolRunner runner;
  fs.add_file("src/main.cpp", "int main() { return 0; }");

  SecretsCheck check;
  auto findings = check.run(fs, runner);
  CHECK(findings.empty());
}

TEST_CASE("TodoCheck finds TODO markers") {
  MockFileSystem fs;
  MockToolRunner runner;
  fs.add_file("src/main.cpp", "int x = 0; // TODO fix this\nint y = 1;\n// FIXME broken");

  TodoCheck check;
  auto findings = check.run(fs, runner);
  CHECK(findings.size() == 2);
  CHECK(findings[0].rule == "technical-debt");
  CHECK(findings[0].line == 1);
  CHECK(findings[1].line == 3);
}

TEST_CASE("LockfileCheck detects missing package-lock") {
  MockFileSystem fs;
  MockToolRunner runner;
  fs.add_file("package.json", "{}");

  LockfileCheck check;
  auto findings = check.run(fs, runner);
  CHECK(findings.size() == 1);
  CHECK(findings[0].rule == "missing-lockfile");
  CHECK(findings[0].severity == "error");
}

TEST_CASE("LockfileCheck passes with yarn.lock") {
  MockFileSystem fs;
  MockToolRunner runner;
  fs.add_file("package.json", "{}");
  fs.add_file("yarn.lock", "");

  LockfileCheck check;
  auto findings = check.run(fs, runner);
  CHECK(findings.empty());
}

TEST_CASE("LockfileCheck passes without manifest") {
  MockFileSystem fs;
  MockToolRunner runner;

  LockfileCheck check;
  auto findings = check.run(fs, runner);
  CHECK(findings.empty());
}
