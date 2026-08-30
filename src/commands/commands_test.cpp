/**
// @see ADR-129
 * @file commands_test.cpp
 * @brief Unit tests for CLI command dispatch.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "../../vendor/doctest.h"
#include "commands.h"

TEST_SUITE("commands") {
  SCENARIO("cmd_sort returns error with no arguments") {
    GIVEN("no arguments to cmd_sort") {
      THEN("it returns error code 1") {
        int argc = 0;
        char* argv[] = {nullptr};
        int rc = cmd_sort(argc, argv);
        CHECK(rc == 1);
      }
    }
  }
}
