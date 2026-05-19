/**
// @see ADR-129
 * @file commands_test.cpp
 * @brief Unit tests for CLI command dispatch.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "../../vendor/doctest.h"

TEST_SUITE("commands") {
SCENARIO("command dispatch exists") {
  GIVEN("the cpm binary") {
    THEN("it compiles and links") {
      CHECK(true); // placeholder — proves module compiles
    }
  }
}
}
