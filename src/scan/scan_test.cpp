/**
// @see ADR-129
 * @file scan_test.cpp
 * @brief Unit tests for repo discovery and scanning.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "scan.h"

#include "../../vendor/doctest.h"

TEST_SUITE("scan") {
  SCENARIO("has_file detects existing files") {
    GIVEN("the current directory") {
      WHEN("checking for Makefile") {
        THEN("it exists") { CHECK(has_file(".", "Makefile")); }
      }
      WHEN("checking for nonexistent file") {
        THEN("it returns false") { CHECK_FALSE(has_file(".", "nonexistent_xyz.txt")); }
      }
    }
  }
}
