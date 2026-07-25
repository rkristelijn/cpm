/**
 * @file version_test.cpp
 * @brief Unit tests for version comparison and local check discovery.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "common/version.h"

#include "../vendor/doctest.h"

TEST_SUITE("version_cmp") {
  TEST_CASE("exact match") {
    CHECK(version_cmp("2.13.0", "2.13.0") == 0);
    CHECK(version_cmp("0.33.0", "0.33.0") == 0);
  }
  TEST_CASE("major only match") { CHECK(version_cmp("11", "11") == 0); }
  TEST_CASE("newer installed") {
    CHECK(version_cmp("2.20.0", "2.13.0") == 1);
    CHECK(version_cmp("3.0.0", "2.99.99") == 1);
    CHECK(version_cmp("0.11.0", "0.10.0") == 1);
  }
  TEST_CASE("outdated installed") {
    CHECK(version_cmp("0.33.0", "0.34.0") == -1);
    CHECK(version_cmp("1.9.0", "2.0.0") == -1);
    CHECK(version_cmp("3.7.0", "3.13.1") == -1);
  }
  TEST_CASE("patch difference") {
    CHECK(version_cmp("1.2.3", "1.2.4") == -1);
    CHECK(version_cmp("1.2.4", "1.2.3") == 1);
  }
  TEST_CASE("two-part versions") {
    CHECK(version_cmp("3.9", "3.9") == 0);
    CHECK(version_cmp("3.14", "3.9") == 1);
    CHECK(version_cmp("0.15", "0.24") == -1);
  }
}
