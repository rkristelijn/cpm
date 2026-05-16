/* commands.cpp — CLI command implementations
 *
 * Each cmd_* function implements one CLI command. They share these patterns:
 * - Return 0 on success, non-zero on failure
 * - Use cpm_exec() for shell commands (respects CPM_MOCK for tool calls)
 * - Detect build system automatically (Makefile > CMakeLists.txt > raw compiler)
 *
 * Design: commands are pure side-effects (file I/O, shell calls).
 * Testable via e2e tests with CPM_MOCK=1 for speed.
 */
#include "commands.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "runner.h"
#include "setup.h"
#include "toml.h"
#include "ui.h"

#define CPM_FILE "cpm.toml"
#define CPM_BIN "/usr/local/bin/cpm"

/* --- Utilities --- */

/* Check if a file exists (used for build system detection) */
static bool has_file(const char* path) { return access(path, F_OK) == 0; }

/* Check if Makefile has a specific target (e.g. "build", "test", "clean").
 * Used to prefer explicit targets over generic fallbacks. */
static bool has_target_in_makefile(const char* target) {
  if (!has_file("Makefile")) return false;
  char grep_cmd[256];
  snprintf(grep_cmd, sizeof(grep_cmd), "grep -qE '^%s[[:space:]]*:' Makefile 2>/dev/null", target);
  return cpm_exec(grep_cmd) == 0;
}

/* --- init: bootstrap a new project with cpm.toml --- */

int cmd_init(void) {
  if (access(CPM_FILE, F_OK) == 0) {
    fprintf(stderr, "%s already exists.\n", CPM_FILE);
    return 1;
  }

  /* Derive project name from current directory name */
  char name[128] = "", version[32] = "0.1.0", lang[16] = "cpp";
  char build[16] = "make", cfgdir[128] = ".config";

  char cwd[512];
  if (getcwd(cwd, sizeof(cwd))) {
    const char* base = strrchr(cwd, '/');
    snprintf(name, sizeof(name), "%s", base ? base + 1 : cwd);
  }

  /* Write cpm.toml with sensible defaults for a C++ project */
  FILE* f = fopen(CPM_FILE, "w");
  if (!f) {
    perror("fopen");
    return 1;
  }

  fprintf(f,
          "[project]\n"
          "name = \"%s\"\n"
          "version = \"%s\"\n"
          "lang = \"%s\"\n"
          "build = \"%s\"\n"
          "config-dir = \"%s\"\n"
          "\n[tools]\n"
          "%s"
          "cppcheck = \"2.13\"\n"
          "cloc = \"2.02\"\n"
          "shellcheck = \"0.10.0\"\n"
          "shfmt = \"3.7.0\"\n"
          "yamllint = \"1.33.0\"\n"
          "rumdl = \"0.1.73\"\n"
          "doxygen = \"1.16.1\"\n"
          "semgrep = \"1.56.0\"\n"
          "gitleaks = \"8.18.2\"\n"
          "pmccabe = \"2.8\"\n"
          "\n[checks]\n"
          "code-cpp-syntax-format = true\n"
          "code-yaml-syntax-format = true\n"
          "docs-markdown-syntax-format = true\n"
          "code-scripts-syntax-format = true\n"
          "code-cpp-syntax-lint = true\n"
          "code-cpp-quality-lint = true\n"
          "code-scripts-syntax-lint = true\n"
          "configuration-makefile-policy-validate = true\n"
          "code-cpp-complexity-measure = true\n"
          "code-cpp-comment-measure = true\n"
          "docs-cpp-syntax-validate = true\n"
          "code-generic-vulnerability-scan = true\n"
          "code-generic-secrets-scan = true\n"
          "\n[checks.code-cpp-complexity-measure]\n"
          "threshold = 10\n"
          "\n[checks.code-cpp-comment-measure]\n"
          "threshold = 20\n"
          "\n[hooks]\n"
          "pre-commit = true\n"
          "pre-push = true\n"
          "commit-msg = false\n",
          name, version, lang, build, cfgdir, strcmp(lang, "cpp") == 0 ? "llvm = \"19\"\n" : "");
  fclose(f);
  ui_created(CPM_FILE);
  ui_info("Done. Run 'cpm install' to install tools.");
  return 0;
}

/* --- new: scaffold projects, tests, and modules --- */

int cmd_new(int argc, char* argv[]) {
  if (argc < 3) {
    printf(
        "Usage:\n"
        "  cpm new <project-name>   Create a new project\n"
        "  cpm new test <path>       Create a new test file\n"
        "  cpm new module <name>     Create a new module (cpp + hpp)\n");
    return 1;
  }

  const char* type = argv[2];

  /* "cpm new test <name>" — create a test file in src/ */
  if (strcmp(type, "test") == 0) {
    if (argc < 4) {
      printf("Missing test name.\n");
      return 1;
    }
    char path[256];
    snprintf(path, sizeof(path), "src/%s_test.cpp", argv[3]);
    if (has_file(path)) {
      printf("  %s already exists.\n", path);
      return 1;
    }
    cpm_exec("mkdir -p src");
    FILE* f = fopen(path, "w");
    fprintf(f, "#include <iostream>\n\nint main() {\n    return 0;\n}\n");
    fclose(f);
    ui_created(path);
  }
  /* "cpm new module <name>" — create .cpp + .hpp pair */
  else if (strcmp(type, "module") == 0) {
    if (argc < 4) {
      printf("Missing module name.\n");
      return 1;
    }
    cpm_exec("mkdir -p src");
    char cpp[256], hpp[256];
    snprintf(cpp, sizeof(cpp), "src/%s.cpp", argv[3]);
    snprintf(hpp, sizeof(hpp), "src/%s.hpp", argv[3]);
    if (!has_file(cpp)) {
      FILE* f = fopen(cpp, "w");
      fprintf(f, "#include \"%s.hpp\"\n", argv[3]);
      fclose(f);
      ui_created(cpp);
    }
    if (!has_file(hpp)) {
      FILE* f = fopen(hpp, "w");
      fprintf(f, "#pragma once\n\nclass %s {\n};\n", argv[3]);
      fclose(f);
      ui_created(hpp);
    }
  }
  /* "cpm new <name>" — create entire project directory */
  else {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "mkdir -p %s", type);
    if (cpm_exec(cmd) != 0) return 1;
    if (chdir(type) != 0) return 1;
    cmd_init();
    cpm_exec("mkdir -p src");
    FILE* f = fopen("src/main.cpp", "w");
    fprintf(f,
            "#include <iostream>\n\nint main() {\n"
            "    std::cout << \"Hello from %s!\" << std::endl;\n"
            "    return 0;\n}\n",
            type);
    fclose(f);
    ui_created("src/main.cpp");
  }
  return 0;
}

/* --- install / uninstall --- */

int cmd_install(CpmConfig* cfg) {
  int rc = cpm_setup(cfg);
  printf("\nTo install cpm globally: sudo cp cpm %s\n", CPM_BIN);
  return rc;
}

int cmd_uninstall(int argc, char* argv[]) {
  bool all = argc > 2 && strcmp(argv[2], "--all") == 0;
  if (access(CPM_BIN, F_OK) == 0) {
    printf("Removing %s (may need sudo)\n", CPM_BIN);
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "sudo rm -f %s", CPM_BIN);
    cpm_exec(cmd);
  } else {
    printf("cpm not found at %s\n", CPM_BIN);
  }
  if (all) {
    printf("Note: tool uninstall not yet implemented. Use brew/apt to remove individual tools.\n");
  }
  return 0;
}

/* --- build: detect build system and compile ---
 *
 * Priority order:
 * 1. Explicit cmake in cpm.toml + CMakeLists.txt
 * 2. Makefile with 'build' target
 * 3. CMakeLists.txt (auto-detect)
 * 4. Makefile default goal
 * 5. Raw compiler fallback (find all .cpp, compile)
 */
int cmd_build(CpmConfig* cfg) {
  if (strcmp(cfg->build, "cmake") == 0 && has_file("CMakeLists.txt")) {
    printf("cpm build → cmake\n");
    if (cpm_exec("cmake -B build -S . 2>&1") != 0) return 1;
    return cpm_exec("cmake --build build 2>&1");
  }
  if (has_target_in_makefile("build")) {
    printf("cpm build → Makefile\n");
    return cpm_exec("make build 2>&1");
  }
  if (has_file("CMakeLists.txt")) {
    printf("cpm build → CMakeLists.txt\n");
    if (cpm_exec("cmake -B build -S . 2>&1") != 0) return 1;
    return cpm_exec("cmake --build build 2>&1");
  }
  if (has_file("Makefile")) {
    return cpm_exec("make 2>&1");
  }

  /* Fallback: compile all source files directly */
  char cmd[1024];
  if (strcmp(cfg->lang, "cpp") == 0) {
    snprintf(cmd, sizeof(cmd), "g++ -Wall -O2 -I src %s $(find src -name '*.cpp' ! -name '*_test.cpp') -o %s %s 2>&1", cfg->cflags,
             cfg->name, cfg->ldflags);
  } else {
    snprintf(cmd, sizeof(cmd), "gcc -Wall -O2 -I src %s $(find src -name '*.c' ! -name '*_test.c') -o %s %s 2>&1", cfg->cflags, cfg->name,
             cfg->ldflags);
  }
  int rc = cpm_exec(cmd);

  /* Build extra binaries from [binaries] section */
  for (int i = 0; i < cfg->binary_count && rc == 0; i++) {
    const char* cc = strcmp(cfg->lang, "cpp") == 0 ? "g++" : "gcc";
    snprintf(cmd, sizeof(cmd), "%s -Wall -O2 -I src %s %s -o %s %s 2>&1", cc, cfg->cflags, cfg->binaries[i].source, cfg->binaries[i].name,
             cfg->ldflags);
    rc = cpm_exec(cmd);
  }
  return rc;
}

/* --- run: build then execute --- */
int cmd_run(CpmConfig* cfg) {
  int rc = cmd_build(cfg);
  if (rc != 0) return rc;
  char cmd[256];
  snprintf(cmd, sizeof(cmd), "./%s", cfg->name);
  printf("cpm run → %s\n", cmd);
  return cpm_exec(cmd);
}

/* --- test: find and run tests ---
 *
 * Same priority as build: Makefile target > CTest > generic fallback.
 */
int cmd_test(CpmConfig* cfg) {
  if (has_target_in_makefile("test")) return cpm_exec("make test 2>&1");
  if (has_file("CMakeLists.txt") && has_file("build/CTestTestfile.cmake")) return cpm_exec("cd build && ctest --output-on-failure 2>&1");
  if (has_target_in_makefile("test-unit")) return cpm_exec("make test-unit 2>&1");
  if (has_target_in_makefile("check")) return cpm_exec("make check 2>&1");

  /* Fallback: compile and run each *_test.cpp individually */
  char cmd[1024];
  if (strcmp(cfg->lang, "cpp") == 0) {
    snprintf(cmd, sizeof(cmd),
             "for f in $(find src tests -name '*_test.cpp' -o -name 'test_*.cpp' 2>/dev/null); do "
             "  echo \"Testing $f...\"; "
             "  g++ -Wall -O2 -I src %s $f $(find src -name '*.cpp' ! -name '*_test.cpp' ! -name 'main.cpp') "
             "  -o test_bin %s && ./test_bin || exit 1; "
             "done; rm -f test_bin",
             cfg->cflags, cfg->ldflags);
  } else {
    snprintf(cmd, sizeof(cmd),
             "for f in $(find src tests -name '*_test.c' -o -name 'test_*.c' 2>/dev/null); do "
             "  echo \"Testing $f...\"; "
             "  gcc -Wall -O2 -I src %s $f $(find src -name '*.c' ! -name '*_test.c' ! -name 'main.c') "
             "  -o test_bin %s && ./test_bin || exit 1; "
             "done; rm -f test_bin",
             cfg->cflags, cfg->ldflags);
  }
  return cpm_exec(cmd);
}

/* --- coverage: build with gcov instrumentation, report via lcov --- */
int cmd_coverage(CpmConfig* cfg) {
  printf("cpm coverage\n");
  if (has_target_in_makefile("coverage")) return cpm_exec("make coverage 2>&1");

  char cmd[1024];
  const char* cc = strcmp(cfg->lang, "cpp") == 0 ? "g++" : "gcc";
  const char* ext = strcmp(cfg->lang, "cpp") == 0 ? "cpp" : "c";
  snprintf(cmd, sizeof(cmd),
           "mkdir -p .tmp/cov && "
           "%s -Wall -O2 -I src --coverage "
           "$(find src tests -name '*.%s' ! -name 'main.%s' 2>/dev/null) "
           "-o .tmp/cov/cov_bin 2>&1 && .tmp/cov/cov_bin && "
           "LCOV_OPTS='--ignore-errors inconsistent,unsupported,corrupt,unused' && "
           "lcov --capture --directory . --output-file .tmp/cov/coverage.info --quiet $LCOV_OPTS 2>&1 && "
           "lcov --remove .tmp/cov/coverage.info '/usr/*' --output-file .tmp/cov/coverage.info --quiet $LCOV_OPTS 2>&1 && "
           "lcov --summary .tmp/cov/coverage.info $LCOV_OPTS; "
           "rm -f *.gcda *.gcno .tmp/cov/cov_bin .tmp/cov/*.gcda .tmp/cov/*.gcno",
           cc, ext, ext);
  return cpm_exec(cmd);
}

/* --- clean: remove build artifacts --- */
int cmd_clean(CpmConfig* cfg) {
  printf("cpm clean\n");
  if (has_target_in_makefile("clean")) return cpm_exec("make clean 2>&1");
  if (has_file("build/Makefile")) return cpm_exec("cmake --build build --target clean 2>&1");
  char cmd[512];
  snprintf(cmd, sizeof(cmd), "rm -rf %s test_bin .tmp/cov *.gcda *.gcno", cfg->name);
  int rc = cpm_exec(cmd);
  for (int i = 0; i < cfg->binary_count; i++) {
    snprintf(cmd, sizeof(cmd), "rm -f %s", cfg->binaries[i].name);
    cpm_exec(cmd);
  }
  return rc;
}

/* --- eject: generate standalone build configs ---
 *
 * Creates .clang-format, .clang-tidy, yamllint.yml, rumdl.toml, Doxyfile,
 * Makefile, and CMakeLists.txt so the project works without cpm.
 */
int cmd_eject(CpmConfig* cfg) {
  printf("Ejecting configuration and build system boilerplate...\n");

  const char* cfgdir = cfg->config_dir;
  if (strcmp(cfgdir, ".") != 0) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "mkdir -p %s", cfgdir);
    cpm_exec(cmd);
  }

  char path[256];
  FILE* f;

  /* Linter/formatter configs — only create if missing */
  snprintf(path, sizeof(path), "%s/.clang-format", cfgdir);
  if (!has_file(path)) {
    f = fopen(path, "w");
    fprintf(f, "BasedOnStyle: Google\nIndentWidth: 2\nColumnLimit: 140\nPointerAlignment: Left\n");
    fclose(f);
    ui_created(path);
  }

  snprintf(path, sizeof(path), "%s/.clang-tidy", cfgdir);
  if (!has_file(path)) {
    f = fopen(path, "w");
    fprintf(f,
            "Checks: 'readability-*,bugprone-*,misc-*'\nCheckOptions:\n"
            "  - key: readability-function-size.LineThreshold\n    value: '40'\n");
    fclose(f);
    ui_created(path);
  }

  snprintf(path, sizeof(path), "%s/yamllint.yml", cfgdir);
  if (!has_file(path)) {
    f = fopen(path, "w");
    fprintf(f, "extends: default\nrules:\n  line-length: {max: 140}\n  document-start: disable\n");
    fclose(f);
    ui_created(path);
  }

  snprintf(path, sizeof(path), "%s/rumdl.toml", cfgdir);
  if (!has_file(path)) {
    f = fopen(path, "w");
    fprintf(f, "[global]\nexclude = [\"node_modules\"]\nrespect-gitignore = true\n");
    fclose(f);
    ui_created(path);
  }

  snprintf(path, sizeof(path), "%s/Doxyfile", cfgdir);
  if (!has_file(path)) {
    f = fopen(path, "w");
    fprintf(f,
            "PROJECT_NAME = %s\nINPUT = src\nRECURSIVE = YES\n"
            "GENERATE_HTML = NO\nGENERATE_LATEX = NO\n",
            cfg->name);
    fclose(f);
    ui_created(path);
  }

  /* Build system files */
  if (!has_file("Makefile")) {
    f = fopen("Makefile", "w");
    fprintf(f,
            "CXX      = g++\nCXXFLAGS = -Wall -Wextra -std=c++17 -O2 -I src\nBINARY   = %s\n"
            "SRCS     = $(wildcard src/*.cpp)\n\n.PHONY: all build clean test\n\n"
            "all: build\n\nbuild: $(BINARY)\n\n$(BINARY): $(SRCS)\n\t$(CXX) $(CXXFLAGS) -o $@ $(SRCS)\n\n"
            "test:\n\t@find src -name '*_test.cpp' | xargs -I{} $(CXX) $(CXXFLAGS) {} -o test_bin && ./test_bin && rm test_bin\n\n"
            "clean:\n\trm -f $(BINARY) test_bin\n",
            cfg->name);
    fclose(f);
    ui_created("Makefile");
  }

  if (!has_file("CMakeLists.txt")) {
    f = fopen("CMakeLists.txt", "w");
    fprintf(f,
            "cmake_minimum_required(VERSION 3.15)\nproject(%s VERSION %s)\n\n"
            "set(CMAKE_CXX_STANDARD 17)\nset(CMAKE_CXX_STANDARD_REQUIRED ON)\n\n"
            "include_directories(src)\n\nfile(GLOB_RECURSE SOURCES \"src/*.cpp\")\n"
            "add_executable(${PROJECT_NAME} ${SOURCES})\n\n"
            "enable_testing()\nfile(GLOB_RECURSE TEST_SOURCES \"src/*_test.cpp\")\n"
            "foreach(test_src ${TEST_SOURCES})\n    get_filename_component(test_name ${test_src} NAME_WE)\n"
            "    add_executable(${test_name} ${test_src})\n    add_test(NAME ${test_name} COMMAND ${test_name})\n"
            "endforeach()\n",
            cfg->name, cfg->version);
    fclose(f);
    ui_created("CMakeLists.txt");
  }

  return 0;
}

/* --- hook/unhook: install/remove git hooks ---
 *
 * Hooks are inline scripts (not copied from files) so cpm works
 * without any scripts committed to the repo.
 */
int cmd_hook(CpmConfig* cfg) {
  printf("Installing git hooks...\n");
  if (cfg->hook_pre_commit)
    cpm_exec("mkdir -p .git/hooks && printf '#!/bin/sh\\ncpm check --fast\\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit");
  if (cfg->hook_pre_push)
    cpm_exec("mkdir -p .git/hooks && printf '#!/bin/sh\\ncpm check\\n' > .git/hooks/pre-push && chmod +x .git/hooks/pre-push");
  if (cfg->hook_commit_msg)
    cpm_exec(
        "mkdir -p .git/hooks && printf '#!/bin/sh\\n# conventional commit check\\n' > .git/hooks/commit-msg && chmod +x "
        ".git/hooks/commit-msg");
  printf("Done.\n");
  return 0;
}

int cmd_unhook(void) {
  printf("Removing git hooks...\n");
  cpm_exec("rm -f .git/hooks/pre-commit .git/hooks/pre-push .git/hooks/commit-msg");
  printf("Done.\n");
  return 0;
}

/* --- bump: semantic version increment ---
 *
 * Reads current version from cpm.toml, increments the specified part,
 * writes back using sed (portable, no TOML library needed for write).
 */
int cmd_bump(CpmConfig* cfg, const char* part) {
  if (!part || (strcmp(part, "major") != 0 && strcmp(part, "minor") != 0 && strcmp(part, "patch") != 0)) {
    fprintf(stderr, "Usage: cpm bump <major|minor|patch>\n");
    return 1;
  }

  int major = 0, minor = 0, patch = 0;
  sscanf(cfg->version, "%d.%d.%d", &major, &minor, &patch);

  if (strcmp(part, "major") == 0) {
    major++;
    minor = 0;
    patch = 0;
  } else if (strcmp(part, "minor") == 0) {
    minor++;
    patch = 0;
  } else {
    patch++;
  }

  char newver[32];
  snprintf(newver, sizeof(newver), "%d.%d.%d", major, minor, patch);

  /* Use sed to update in-place (works on macOS and Linux) */
  char cmd[512];
  snprintf(cmd, sizeof(cmd), "sed -i '' 's/^version = \".*\"/version = \"%s\"/' %s", newver, CPM_FILE);
  cpm_exec(cmd);

  printf("%s → %s\n", cfg->version, newver);
  return 0;
}

/* --- audit: compare installed tool versions against cpm.toml pins --- */
int cmd_audit(CpmConfig* cfg) {
  printf("cpm audit — checking tool versions\n\n");
  cpm_versions(cfg);
  printf("\nNote: version mismatch detection coming soon.\n");
  return 0;
}

/* --- get/set: read and write cpm.toml values --- */

int cmd_get(CpmConfig* cfg, const char* key) {
  if (!key) {
    /* Show all config sections */
    printf("[project]\n");
    printf("  name    = %s\n", cfg->name);
    printf("  version = %s\n", cfg->version);
    printf("  lang    = %s\n", cfg->lang);
    printf("  build   = %s\n", cfg->build);
    printf("\n[checks] (%d)\n", cfg->check_count);
    for (int i = 0; i < cfg->check_count; i++) {
      CpmCheck* c = &cfg->checks[i];
      printf("  %-20s %s%s\n", c->name, c->enabled ? "on" : "off", c->warn_only ? " (warn)" : "");
    }
    printf("\n[hooks]\n");
    printf("  pre-commit = %s\n", cfg->hook_pre_commit ? "true" : "false");
    printf("  pre-push   = %s\n", cfg->hook_pre_push ? "true" : "false");
    printf("  commit-msg = %s\n", cfg->hook_commit_msg ? "true" : "false");
    return 0;
  }

  /* Get specific key */
  if (strcmp(key, "name") == 0)
    printf("%s\n", cfg->name);
  else if (strcmp(key, "version") == 0)
    printf("%s\n", cfg->version);
  else if (strcmp(key, "lang") == 0)
    printf("%s\n", cfg->lang);
  else if (strcmp(key, "build") == 0)
    printf("%s\n", cfg->build);
  else {
    CpmCheck* c = cpm_check_find(cfg, key);
    if (c)
      printf("%s = %s%s\n", c->name, c->enabled ? "true" : "false", c->warn_only ? " (warn-only)" : "");
    else {
      fprintf(stderr, "Unknown key: %s\n", key);
      return 1;
    }
  }
  return 0;
}

int cmd_set(const char* key, const char* val) {
  if (!key || !val) {
    fprintf(stderr, "Usage: cpm set <key> <value>\n");
    return 1;
  }
  /* Use sed for in-place update (same approach as bump) */
  char cmd[512];
  snprintf(cmd, sizeof(cmd), "sed -i '' 's/^%s = .*/%s = %s/' %s", key, key, val, CPM_FILE);
  cpm_exec(cmd);
  printf("%s = %s\n", key, val);
  return 0;
}

/* --- findings: query the findings database ---
 *
 * Usage:
 *   cpm findings              — show all findings
 *   cpm findings <repo>       — filter by repo name
 *   cpm findings --severity error  — filter by severity
 *   cpm findings --junit      — output as JUnit XML
 */
int cmd_findings(int argc, char* argv[]) {
  const char* home = getenv("HOME");
  if (!home) home = ".";

  /* Read from both scan and check findings (unified view) */
  const char* files[] = {
    "%s/.local/share/cpm/scan-findings.jsonl",
    "%s/.local/share/cpm/check-findings.jsonl",
    NULL
  };
  char path[512];
  FILE* f = NULL;

  /* Try scan findings first */
  snprintf(path, sizeof(path), files[0], home);
  f = fopen(path, "r");
  if (!f) {
    snprintf(path, sizeof(path), files[1], home);
    f = fopen(path, "r");
  }
  if (!f) {
    ui_error("No findings. Run 'cpm scan' or 'cpm check' first.");
    return 1;
  }

  /* Parse filters from args */
  const char* repo_filter = NULL;
  const char* severity_filter = NULL;
  bool junit = false;

  for (int i = 0; i < argc; i++) {
    if (strcmp(argv[i], "--severity") == 0 && i + 1 < argc) {
      severity_filter = argv[++i];
    } else if (strcmp(argv[i], "--junit") == 0) {
      junit = true;
    } else if (argv[i][0] != '-') {
      repo_filter = argv[i];
    }
  }

  /* JUnit XML header */
  if (junit) printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<testsuites>\n<testsuite name=\"cpm-findings\">\n");

  char line[2048];
  int count = 0;
  const CpmTheme* t = ui_theme();

  while (fgets(line, sizeof(line), f)) {
    /* Quick substring filters on raw JSON (fast, no parser needed) */
    if (repo_filter && !strstr(line, repo_filter)) continue;
    if (severity_filter && !strstr(line, severity_filter)) continue;

    if (junit) {
      /* Extract fields for JUnit */
      char repo[128] = "", check[128] = "", sev[32] = "", msg[512] = "";
      sscanf(strstr(line, "\"repo\":\"") ? strstr(line, "\"repo\":\"") + 8 : "", "%127[^\"]", repo);
      sscanf(strstr(line, "\"check\":\"") ? strstr(line, "\"check\":\"") + 9 : "", "%127[^\"]", check);
      sscanf(strstr(line, "\"severity\":\"") ? strstr(line, "\"severity\":\"") + 12 : "", "%31[^\"]", sev);
      sscanf(strstr(line, "\"message\":\"") ? strstr(line, "\"message\":\"") + 11 : "", "%511[^\"]", msg);
      if (strcmp(sev, "error") == 0)
        printf("  <testcase name=\"%s/%s\"><failure message=\"%s\"/></testcase>\n", repo, check, msg);
      else
        printf("  <testcase name=\"%s/%s\"><!-- %s: %s --></testcase>\n", repo, check, sev, msg);
    } else {
      /* Pretty-print: colored severity + repo + message */
      char repo[128] = "", check[128] = "", sev[32] = "", msg[512] = "";
      sscanf(strstr(line, "\"repo\":\"") ? strstr(line, "\"repo\":\"") + 8 : "", "%127[^\"]", repo);
      sscanf(strstr(line, "\"check\":\"") ? strstr(line, "\"check\":\"") + 9 : "", "%127[^\"]", check);
      sscanf(strstr(line, "\"severity\":\"") ? strstr(line, "\"severity\":\"") + 12 : "", "%31[^\"]", sev);
      sscanf(strstr(line, "\"message\":\"") ? strstr(line, "\"message\":\"") + 11 : "", "%511[^\"]", msg);

      const char* color = strcmp(sev, "error") == 0 ? t->error : t->warning;
      printf("  %s%-7s%s %-20s %-15s %s\n", color, sev, t->reset, repo, check, msg);
    }
    count++;
  }

  fclose(f);

  /* Also read check-findings if we started with scan-findings */
  char path2[512];
  snprintf(path2, sizeof(path2), files[1], home);
  FILE* f2 = fopen(path2, "r");
  if (f2) {
    while (fgets(line, sizeof(line), f2)) {
      if (repo_filter && !strstr(line, repo_filter)) continue;
      if (severity_filter && !strstr(line, severity_filter)) continue;

      if (junit) {
        char repo[128] = "", check[128] = "", sev[32] = "", msg[512] = "";
        sscanf(strstr(line, "\"check\":\"") ? strstr(line, "\"check\":\"") + 9 : "", "%127[^\"]", check);
        sscanf(strstr(line, "\"severity\":\"") ? strstr(line, "\"severity\":\"") + 12 : "", "%31[^\"]", sev);
        sscanf(strstr(line, "\"message\":\"") ? strstr(line, "\"message\":\"") + 11 : "", "%511[^\"]", msg);
        sscanf(strstr(line, "\"rule\":\"") ? strstr(line, "\"rule\":\"") + 8 : "", "%127[^\"]", repo);
        printf("  <testcase name=\"check/%s\"><failure message=\"%s\"/></testcase>\n", check, msg);
      } else {
        char check[128] = "", sev[32] = "", msg[512] = "";
        sscanf(strstr(line, "\"check\":\"") ? strstr(line, "\"check\":\"") + 9 : "", "%127[^\"]", check);
        sscanf(strstr(line, "\"severity\":\"") ? strstr(line, "\"severity\":\"") + 12 : "", "%31[^\"]", sev);
        sscanf(strstr(line, "\"message\":\"") ? strstr(line, "\"message\":\"") + 11 : "", "%511[^\"]", msg);
        const char* color = strcmp(sev, "error") == 0 ? t->error : t->warning;
        printf("  %s%-7s%s %-20s %-15s %s\n", color, sev, t->reset, ".", check, msg);
      }
      count++;
    }
    fclose(f2);
  }

  if (junit) printf("</testsuite>\n</testsuites>\n");
  else printf("\n  %d finding(s)\n", count);

  return 0;
}

/* --- report: generate aggregate markdown report from findings ---
 *
 * Reads scan-findings.jsonl and produces a summary like:
 * - Total repos, findings by severity, by check category
 * - Top offenders (repos with most findings)
 * - Trend comparison (if previous report exists)
 */
int cmd_report(int argc, char* argv[]) {
  (void)argc; (void)argv;
  const char* home = getenv("HOME");
  if (!home) home = ".";
  char path[512];
  snprintf(path, sizeof(path), "%s/.local/share/cpm/scan-findings.jsonl", home);

  FILE* f = fopen(path, "r");
  if (!f) {
    ui_error("No findings. Run 'cpm scan' first.");
    return 1;
  }

  /* Count findings by severity and check */
  int total = 0, errors = 0, warnings = 0;
  char checks[64][128];
  int check_counts[64] = {};
  int check_count = 0;
  char repos[256][128];
  int repo_counts[256] = {};
  int repo_count = 0;

  char line[2048];
  while (fgets(line, sizeof(line), f)) {
    total++;

    /* Count severity */
    if (strstr(line, "\"error\"")) errors++;
    else warnings++;

    /* Count by check */
    char check[128] = "";
    const char* cp = strstr(line, "\"check\":\"");
    if (cp) sscanf(cp + 9, "%127[^\"]", check);
    int found = 0;
    for (int i = 0; i < check_count; i++) {
      if (strcmp(checks[i], check) == 0) { check_counts[i]++; found = 1; break; }
    }
    if (!found && check_count < 64) {
      strncpy(checks[check_count], check, 127);
      check_counts[check_count] = 1;
      check_count++;
    }

    /* Count by repo */
    char repo[128] = "";
    const char* rp = strstr(line, "\"repo\":\"");
    if (rp) sscanf(rp + 8, "%127[^\"]", repo);
    found = 0;
    for (int i = 0; i < repo_count; i++) {
      if (strcmp(repos[i], repo) == 0) { repo_counts[i]++; found = 1; break; }
    }
    if (!found && repo_count < 256) {
      strncpy(repos[repo_count], repo, 127);
      repo_counts[repo_count] = 1;
      repo_count++;
    }
  }
  fclose(f);

  /* Print markdown report */
  printf("# cpm Scan Report\n\n");
  printf("Generated: %s\n\n", __DATE__);
  printf("## Summary\n\n");
  printf("| Metric | Count |\n");
  printf("|--------|-------|\n");
  printf("| **Total Repos** | %d |\n", repo_count);
  printf("| **Total Findings** | %d |\n", total);
  printf("| **Errors** | %d |\n", errors);
  printf("| **Warnings** | %d |\n", warnings);
  printf("| **Clean Repos** | %d |\n\n", repo_count > 0 ? repo_count - (int)(total > 0) : 0);

  /* Findings by check */
  printf("## Findings by Check\n\n");
  printf("| Check | Count |\n");
  printf("|-------|-------|\n");
  /* Sort by count descending (simple bubble sort) */
  for (int i = 0; i < check_count - 1; i++)
    for (int j = i + 1; j < check_count; j++)
      if (check_counts[j] > check_counts[i]) {
        int tmp = check_counts[i]; check_counts[i] = check_counts[j]; check_counts[j] = tmp;
        char t[128]; strcpy(t, checks[i]); strcpy(checks[i], checks[j]); strcpy(checks[j], t);
      }
  for (int i = 0; i < check_count; i++)
    printf("| %s | %d |\n", checks[i], check_counts[i]);

  /* Top offenders */
  printf("\n## Top Offenders\n\n");
  printf("| Repo | Findings |\n");
  printf("|------|----------|\n");
  for (int i = 0; i < repo_count - 1; i++)
    for (int j = i + 1; j < repo_count; j++)
      if (repo_counts[j] > repo_counts[i]) {
        int tmp = repo_counts[i]; repo_counts[i] = repo_counts[j]; repo_counts[j] = tmp;
        char t[128]; strcpy(t, repos[i]); strcpy(repos[i], repos[j]); strcpy(repos[j], t);
      }
  for (int i = 0; i < repo_count && i < 10; i++)
    printf("| %s | %d |\n", repos[i], repo_counts[i]);

  printf("\n---\n*Generated by cpm %s*\n", "0.1.0");
  return 0;
}
