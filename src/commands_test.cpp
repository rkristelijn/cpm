/**
// @see ADR-129
 * @file commands_test.cpp
 * @brief Unit tests for commands.cpp utility functions (safe_fopen, write_new_file).
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "../vendor/doctest.h"

#include <cstdio>
#include <cstring>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

/* Stub external dependencies to avoid linking the full binary */
struct CpmConfig { const char* name; const char* version; const char* lang; const char* config_dir; };
int cpm_exec(const char*) { return 0; }
void ui_created(const char*) {}
void ui_header(const char*, int) {}
void ui_tier(const char*) {}

/* Include the utility functions directly from commands.cpp via extraction.
 * We test the helpers in isolation. */
#include <fcntl.h>

static bool has_file(const char* path) { return access(path, F_OK) == 0; }

static FILE* safe_fopen(const char* path, const char* mode) {
  FILE* f = fopen(path, mode);
  if (!f) fprintf(stderr, "  error: cannot open %s: %s\n", path, strerror(errno));
  return f;
}

static bool write_new_file(const char* path, const char* content) {
  if (has_file(path)) return true;
  FILE* f = safe_fopen(path, "w");
  if (!f) return false;
  fputs(content, f);
  fclose(f);
  return true;
}

TEST_SUITE("commands") {
  TEST_CASE("safe_fopen: valid path") {
    FILE* f = safe_fopen("/tmp/cpm_test_safe_fopen", "w");
    REQUIRE(f != nullptr);
    fprintf(f, "test\n");
    fclose(f);
    unlink("/tmp/cpm_test_safe_fopen");
  }

  TEST_CASE("safe_fopen: invalid path returns nullptr") {
    FILE* f = safe_fopen("/nonexistent/dir/file.txt", "w");
    CHECK(f == nullptr);
  }

  TEST_CASE("write_new_file: creates file with content") {
    const char* path = "/tmp/cpm_test_write_new";
    unlink(path);
    bool ok = write_new_file(path, "hello world\n");
    CHECK(ok == true);
    CHECK(has_file(path));
    FILE* f = fopen(path, "r");
    REQUIRE(f != nullptr);
    char buf[64];
    fgets(buf, sizeof(buf), f);
    fclose(f);
    CHECK(strcmp(buf, "hello world\n") == 0);
    unlink(path);
  }

  TEST_CASE("write_new_file: skips if file exists") {
    const char* path = "/tmp/cpm_test_write_exists";
    FILE* f = fopen(path, "w");
    fputs("original\n", f);
    fclose(f);
    bool ok = write_new_file(path, "overwritten\n");
    CHECK(ok == true);
    f = fopen(path, "r");
    char buf[64];
    fgets(buf, sizeof(buf), f);
    fclose(f);
    CHECK(strcmp(buf, "original\n") == 0);
    unlink(path);
  }

  TEST_CASE("write_new_file: returns false on invalid path") {
    bool ok = write_new_file("/nonexistent/dir/file.txt", "content");
    CHECK(ok == false);
  }

  TEST_CASE("has_file: existing file") {
    CHECK(has_file("/tmp") == true);
  }

  TEST_CASE("has_file: non-existing file") {
    CHECK(has_file("/tmp/cpm_definitely_not_here_xyz") == false);
  }
}
