/* commands.cpp — CLI command implementations
// @see ADR-129
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

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
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
  /* Use open() with O_EXCL to atomically check+create (no TOCTOU) */
  int fd = open(CPM_FILE, O_WRONLY | O_CREAT | O_EXCL, 0644);
  if (fd < 0) {
    if (errno == EEXIST) fprintf(stderr, "%s already exists.\n", CPM_FILE);
    else perror("open");
    return 1;
  }
  FILE* f = fdopen(fd, "w");

  /* Derive project name from current directory name */
  char name[128] = "", version[32] = CPM_VERSION, lang[16] = "cpp";
  char build[16] = "make", cfgdir[128] = ".config";

  char cwd[512];
  if (getcwd(cwd, sizeof(cwd))) {
    const char* base = strrchr(cwd, '/');
    snprintf(name, sizeof(name), "%s", base ? base + 1 : cwd);
  }

  fprintf(f,
          "# cpm.toml — project quality configuration\n"
          "# https://github.com/rkristelijn/cpm\n"
          "#\n"
          "# Docs:   https://github.com/rkristelijn/cpm/blob/main/docs/features/config.md\n"
          "# Checks: https://github.com/rkristelijn/cpm/blob/main/docs/features/check.md\n"
          "# Levels: learn | guide | guard | enforce\n"
          "#\n"
          "# Run 'cpm check' to validate, 'cpm get' to inspect config.\n"
          "\n[project]\n"
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

  /* Generate .editorconfig if missing */
  if (access(".editorconfig", F_OK) != 0) {
    FILE* ec = fopen(".editorconfig", "w");
    if (ec) {
      fprintf(ec,
              "root = true\n\n"
              "[*]\n"
              "indent_style = space\n"
              "indent_size = 2\n"
              "end_of_line = lf\n"
              "charset = utf-8\n"
              "trim_trailing_whitespace = true\n"
              "insert_final_newline = true\n\n"
              "[Makefile]\n"
              "indent_style = tab\n");
      fclose(ec);
      ui_created(".editorconfig");
    }
  }

  /* Generate SECURITY.md if missing */
  if (access("SECURITY.md", F_OK) != 0) {
    FILE* sec = fopen("SECURITY.md", "w");
    if (sec) {
      fprintf(sec,
              "# Security Policy\n\n"
              "## Reporting a Vulnerability\n\n"
              "If you discover a security vulnerability, please report it responsibly.\n\n"
              "**Do NOT open a public issue.**\n\n"
              "Email: [your-email] or open a private security advisory on GitHub.\n\n"
              "## Response Timeline\n\n"
              "- Acknowledgment: within 48 hours\n"
              "- Fix: within 30 days (critical), 90 days (low)\n");
      fclose(sec);
      ui_created("SECURITY.md");
    }
  }

  /* Generate .github issue/PR templates if missing */
  struct stat st;
  if (stat(".github/ISSUE_TEMPLATE", &st) != 0) {
    system("mkdir -p .github/ISSUE_TEMPLATE");
    FILE* bug = fopen(".github/ISSUE_TEMPLATE/bug_report.md", "w");
    if (bug) {
      fprintf(bug,
              "---\nname: Bug report\nabout: Report a bug\n---\n\n"
              "## Description\n\n## Steps to reproduce\n\n"
              "## Expected behavior\n\n## Actual behavior\n\n"
              "## Environment\n\n- OS:\n- Version:\n");
      fclose(bug);
    }
    FILE* feat = fopen(".github/ISSUE_TEMPLATE/feature_request.md", "w");
    if (feat) {
      fprintf(feat,
              "---\nname: Feature request\nabout: Suggest an idea\n---\n\n"
              "## Problem\n\n## Proposed solution\n\n## Alternatives considered\n");
      fclose(feat);
    }
    ui_created(".github/ISSUE_TEMPLATE/");
  }
  if (stat(".github/pull_request_template.md", &st) != 0) {
    system("mkdir -p .github");
    FILE* pr = fopen(".github/pull_request_template.md", "w");
    if (pr) {
      fprintf(pr,
              "## What\n\n## Why\n\n## How\n\n"
              "## Checklist\n\n"
              "- [ ] Tests pass\n"
              "- [ ] Docs updated\n"
              "- [ ] No new warnings\n");
      fclose(pr);
    }
    ui_created(".github/pull_request_template.md");
  }

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
        "  cpm new module <name>     Create a new module (cpp + hpp)\n"
        "  cpm new adr <title>       Create a new ADR from template\n");
    return 1;
  }

  const char* type = argv[2];

  /* "cpm new adr <title>" — create ADR from template */
  if (strcmp(type, "adr") == 0) {
    if (argc < 4) {
      printf("Missing ADR title.\n");
      return 1;
    }
    /* Find next ADR number */
    int next = 1;
    DIR* d = opendir("docs/adrs");
    if (d) {
      struct dirent* e;
      while ((e = readdir(d))) {
        int n = 0;
        if (sscanf(e->d_name, "adr-%d", &n) == 1 && n >= next) next = n + 1;
      }
      closedir(d);
    }
    /* Build slug from title */
    char slug[256] = {};
    for (int i = 0; argv[3][i] && i < 200; i++) {
      char c = argv[3][i];
      slug[i] = (c >= 'A' && c <= 'Z') ? c + 32 : (c == ' ' || c == '_') ? '-' : c;
    }
    char path[512];
    snprintf(path, sizeof(path), "docs/adrs/adr-%03d-%s.md", next, slug);
    if (has_file(path)) {
      printf("  %s already exists.\n", path);
      return 1;
    }
    system("mkdir -p docs/adrs");
    /* Read template */
    FILE* tmpl = fopen("lib/templates/adr.md", "r");
    FILE* out = fopen(path, "w");
    if (!tmpl || !out) {
      printf("  Cannot create ADR (template missing?)\n");
      return 1;
    }
    char line[1024];
    while (fgets(line, sizeof(line), tmpl)) {
      /* Replace placeholders */
      if (strstr(line, "ADR-XXX"))
        fprintf(out, "# ADR-%03d: %s\n", next, argv[3]);
      else if (strstr(line, "YYYY-MM-DD")) {
        time_t now = time(NULL);
        struct tm* t = localtime(&now);
        fprintf(out, "*Date*: %04d-%02d-%02d\n", t->tm_year + 1900, t->tm_mon + 1, t->tm_mday);
      } else
        fputs(line, out);
    }
    fclose(tmpl);
    fclose(out);
    ui_created(path);
    return 0;
  }

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
    system("mkdir -p src");
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
    system("mkdir -p src");
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
    if (system(cmd) != 0) return 1;
    if (chdir(type) != 0) return 1;
    cmd_init();
    system("mkdir -p src");
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
