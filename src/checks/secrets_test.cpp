// cpm:ignore-file SEC-010 — detector/test source: contains the patterns it checks for
/**
 * @file secrets_test.cpp
 * @brief Unit tests for secret detection check.
 * @see ADR-130 (test architecture — reference implementation)
 * @see ADR-129 (unified findings contract)
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "secrets.cpp"

#include "../../../vendor/doctest.h"
#include "../io/mock_fs.h"
#include "../runners/tool_runner.h"
#include "check.h"

TEST_SUITE("secrets") {
  SCENARIO("detecting hardcoded API keys") {
    GIVEN("a file containing an AWS access key") {
      MockFileSystem fs;
      MockToolRunner r;
      fs.add_file("src/config.cpp", "auto key = \"AKIAIOSFODNN7EXAMPLE\";");

      WHEN("the secrets check runs") {
        auto findings = SecretsCheck().run(fs, r);

        THEN("it reports one error with correct fields") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].severity == "error");
          CHECK(findings[0].rule == "hardcoded-secret");
          CHECK(findings[0].file == "src/config.cpp");
          CHECK(findings[0].line == 1);
          CHECK(findings[0].fix != "");
        }
      }
    }

    GIVEN("a file containing an OpenAI key") {
      MockFileSystem fs;
      MockToolRunner r;
      fs.add_file("src/main.cpp", "auto k = \"sk-12345678901234567890\";");

      WHEN("the secrets check runs") {
        auto findings = SecretsCheck().run(fs, r);

        THEN("it detects the secret") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].severity == "error");
        }
      }
    }
  }

  SCENARIO("ignoring false positives") {
    GIVEN("a file with cpm:ignore annotation") {
      MockFileSystem fs;
      MockToolRunner r;
      fs.add_file("src/main.cpp", "// cpm:ignore secret\nauto k = \"sk-12345678901234567890\";");

      WHEN("the secrets check runs") {
        auto findings = SecretsCheck().run(fs, r);

        THEN("it skips the annotated file") { CHECK(findings.empty()); }
      }
    }
  }

  SCENARIO("clean codebase") {
    GIVEN("a file with no secrets") {
      MockFileSystem fs;
      MockToolRunner r;
      fs.add_file("src/main.cpp", "int main() { return 0; }");

      WHEN("the secrets check runs") {
        auto findings = SecretsCheck().run(fs, r);

        THEN("it reports nothing") { CHECK(findings.empty()); }
      }
    }
  }

}  // TEST_SUITE
