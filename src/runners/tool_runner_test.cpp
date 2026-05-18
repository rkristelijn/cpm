/**
 * @file tool_runner_test.cpp
 * @brief Unit tests for tool runner timeout support.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "tool_runner.h"

#include <cstdlib>

#include "../vendor/doctest.h"

TEST_CASE("RealToolRunner::exec respects CPM_TIMEOUT") {
  setenv("CPM_TIMEOUT", "2", 1);
  RealToolRunner runner;

  SUBCASE("fast command completes normally") {
    auto r = runner.exec("echo hello");
    CHECK(r.exit_code == 0);
    CHECK(r.stdout_str.find("hello") != std::string::npos);
  }

  SUBCASE("slow command is killed with exit 124") {
    auto r = runner.exec("sleep 10");
    CHECK(r.exit_code == 124);
  }

  unsetenv("CPM_TIMEOUT");
}

TEST_CASE("RealToolRunner::exec no timeout when CPM_TIMEOUT=0") {
  setenv("CPM_TIMEOUT", "0", 1);
  RealToolRunner runner;
  auto r = runner.exec("echo fast");
  CHECK(r.exit_code == 0);
  unsetenv("CPM_TIMEOUT");
}
