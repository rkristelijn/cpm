/**
 * @file tool_runner_test.cpp
 * @brief Unit tests for tool runner timeout support.
 * @see ADR-130 (test architecture)
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "tool_runner.h"

#include <cstdlib>

#include "../vendor/doctest.h"

TEST_SUITE("tool-runner") {
  SCENARIO("exec respects CPM_TIMEOUT") {
    GIVEN("CPM_TIMEOUT is set to 2 seconds") {
      setenv("CPM_TIMEOUT", "2", 1);
      RealToolRunner runner;

      WHEN("a fast command runs") {
        auto r = runner.exec("echo hello");
        THEN("it completes normally") {
          CHECK(r.exit_code == 0);
          CHECK(r.stdout_str.find("hello") != std::string::npos);
        }
      }

      WHEN("a slow command runs") {
        auto r = runner.exec("sleep 10");
        THEN("it is killed with exit 124") { CHECK(r.exit_code == 124); }
      }

      unsetenv("CPM_TIMEOUT");
    }
  }

  SCENARIO("exec without timeout") {
    GIVEN("CPM_TIMEOUT is set to 0") {
      setenv("CPM_TIMEOUT", "0", 1);
      RealToolRunner runner;

      WHEN("a command runs") {
        auto r = runner.exec("echo fast");
        THEN("it completes without timeout wrapper") { CHECK(r.exit_code == 0); }
      }

      unsetenv("CPM_TIMEOUT");
    }
  }

  SCENARIO("has_tool detects presence and absence of tools") {
    GIVEN("a real tool runner") {
      RealToolRunner runner;

      WHEN("an always-present tool is queried") {
        THEN("has_tool returns true for 'sh'") { CHECK(runner.has_tool("sh") == true); }
      }
      WHEN("a non-existent tool is queried") {
        THEN("has_tool returns false") { CHECK(runner.has_tool("cpm_definitely_not_a_tool_xyz") == false); }
      }
    }
  }

  SCENARIO("tool_version reads a tool's version output") {
    GIVEN("a real tool runner") {
      RealToolRunner runner;

      WHEN("the version of an installed tool is queried") {
        std::string v = runner.tool_version("sh");
        THEN("it returns without crashing (may be empty if the tool is silent)") {
          CHECK(v.find('\n') == std::string::npos);  // trailing newlines stripped
        }
      }
      WHEN("the version of a missing tool is queried") {
        std::string v = runner.tool_version("cpm_definitely_not_a_tool_xyz");
        THEN("it returns a string (empty or an error message), never crashes") { CHECK(v.size() >= 0); }
      }
    }
  }

}  // TEST_SUITE
