/**
// @see ADR-129
 * @file toml_test.cpp
 * @brief Unit tests for cpm TOML parser.
 *
 * Tests the minimal TOML parser against real-world cpm.toml patterns.
 * Uses temp files (not mocks) because the parser reads from disk.
 * Each test verifies one parsing feature: sections, strings, bools, ints, dotted keys.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "toml.h"

#include <cstdio>
#include <cstring>

#include "../vendor/doctest.h"

// Helper: write a temp cpm.toml and parse it
static int parse_string(const char* content, CpmConfig* cfg) {
  const char* path = "/tmp/cpm_test.toml";
  FILE* f = fopen(path, "w");
  if (!f) return -1;
  fputs(content, f);
  fclose(f);
  int rc = cpm_toml_parse(path, cfg);
  remove(path);
  return rc;
}

TEST_CASE("parse minimal cpm.toml") {
  CpmConfig cfg{};
  int rc = parse_string(
      "[project]\n"
      "name = \"test-project\"\n"
      "version = \"1.2.3\"\n"
      "lang = \"cpp\"\n"
      "build = \"make\"\n",
      &cfg);
  CHECK(rc == 0);
  CHECK(strcmp(cfg.name, "test-project") == 0);
  CHECK(strcmp(cfg.version, "1.2.3") == 0);
  CHECK(strcmp(cfg.lang, "cpp") == 0);
  CHECK(strcmp(cfg.build, "make") == 0);
}

TEST_CASE("parse tools section") {
  CpmConfig cfg{};
  int rc = parse_string(
      "[project]\nname = \"x\"\nversion = \"0.1.0\"\nlang = \"cpp\"\nbuild = \"make\"\n"
      "\n[tools]\n"
      "clang-format = \"19\"\n"
      "cppcheck = \"2.13\"\n",
      &cfg);
  CHECK(rc == 0);
  CHECK(cfg.tool_count == 2);
  CpmTool* t = cpm_tool_find(&cfg, "clang-format");
  REQUIRE(t != nullptr);
  CHECK(strcmp(t->version, "19") == 0);
}

TEST_CASE("parse checks with threshold") {
  CpmConfig cfg{};
  int rc = parse_string(
      "[project]\nname = \"x\"\nversion = \"0.1.0\"\nlang = \"cpp\"\nbuild = \"make\"\n"
      "\n[checks]\n"
      "lint-code = true\n"
      "format-code = false\n"
      "\n[checks.lint-code]\n"
      "threshold = 15\n",
      &cfg);
  CHECK(rc == 0);
  CpmCheck* c = cpm_check_find(&cfg, "lint-code");
  REQUIRE(c != nullptr);
  CHECK(c->enabled == true);
  CHECK(c->threshold == 15);
  CpmCheck* f = cpm_check_find(&cfg, "format-code");
  REQUIRE(f != nullptr);
  CHECK(f->enabled == false);
}

TEST_CASE("parse hooks section") {
  CpmConfig cfg{};
  int rc = parse_string(
      "[project]\nname = \"x\"\nversion = \"0.1.0\"\nlang = \"cpp\"\nbuild = \"make\"\n"
      "\n[hooks]\n"
      "pre-commit = true\n"
      "pre-push = false\n"
      "commit-msg = true\n",
      &cfg);
  CHECK(rc == 0);
  CHECK(cfg.hook_pre_commit == true);
  CHECK(cfg.hook_pre_push == false);
  CHECK(cfg.hook_commit_msg == true);
}

TEST_CASE("missing file returns error") {
  CpmConfig cfg{};
  int rc = cpm_toml_parse("/tmp/nonexistent_cpm_test.toml", &cfg);
  CHECK(rc != 0);
}

TEST_CASE("cpm_tool_find returns null for unknown tool") {
  CpmConfig cfg{};
  parse_string("[project]\nname = \"x\"\nversion = \"0.1.0\"\nlang = \"c\"\nbuild = \"make\"\n", &cfg);
  CHECK(cpm_tool_find(&cfg, "nonexistent") == nullptr);
}

TEST_CASE("cpm_check_find returns null for unknown check") {
  CpmConfig cfg{};
  parse_string("[project]\nname = \"x\"\nversion = \"0.1.0\"\nlang = \"c\"\nbuild = \"make\"\n", &cfg);
  CHECK(cpm_check_find(&cfg, "nonexistent") == nullptr);
}
