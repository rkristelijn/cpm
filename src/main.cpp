/* main.cpp — cpm: C Project Manager
 *
 * Usage: cpm <command>
 */
#include "runner.h"
#include "setup.h"
#include "toml.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CPM_VERSION "0.1.0"
#define CPM_FILE    "cpm.toml"
#define CPM_BIN     "/usr/local/bin/cpm"

/* --- Check/format definitions --- */

/* Template commands use %s for config_dir path */
typedef struct { const char *name; const char *tmpl; const char *tool; } CheckDef;

/* Standard styles used if local config files are missing */
#define DEFAULT_CLANG_FORMAT "{BasedOnStyle: Google, IndentWidth: 2, ColumnLimit: 140, PointerAlignment: Left}"
#define DEFAULT_CLANG_TIDY   "{Checks: 'readability-*,bugprone-*,misc-*', CheckOptions: [{key: readability-function-size.LineThreshold, value: '40'}]}"

static const CheckDef CHECK_DEFS[] = {
    {"code-cpp-syntax-format",   "find src -name '*.cpp' -o -name '*.c' -o -name '*.h' 2>/dev/null "
                                 "| xargs clang-format --dry-run -Werror "
                                 "--style=\"$(if [ -f .clang-format ]; then echo 'file'; else echo '" DEFAULT_CLANG_FORMAT "'; fi)\" 2>&1", "clang-format"},
    {"code-yaml-syntax-format",   "find . -name '*.yml' -o -name '*.yaml' 2>/dev/null "
                                 "| grep -v node_modules | grep -v .git "
                                 "| xargs yamllint $(if [ -f yamllint.yml ]; then echo '-c yamllint.yml'; elif [ -f .config/yamllint.yml ]; then echo '-c .config/yamllint.yml'; else echo '-d \"{extends: default, rules: {line-length: {max: 140}, document-start: disable}}\"'; fi) 2>&1", "yamllint"},
    {"docs-markdown-syntax-format", "rumdl check $(if [ -f rumdl.toml ]; then echo '--config rumdl.toml'; elif [ -f .config/rumdl.toml ]; then echo '--config .config/rumdl.toml'; else echo '--disable MD013,MD033,MD036,MD041,MD046 --cache-dir .tmp/rumdl'; fi) . 2>&1", "rumdl"},
    {"code-scripts-syntax-format", "find scripts -name '*.sh' 2>/dev/null | xargs shfmt -d -i 2 2>&1 || true", "shfmt"},
    {"code-cpp-syntax-lint",      "cppcheck --enable=all --suppress=missingIncludeSystem "
                                 "--suppress=unusedFunction --error-exitcode=1 -I src src/ 2>&1", "cppcheck"},
    {"code-cpp-quality-lint",     "find src -name '*.cpp' -o -name '*.c' "
                                 "| xargs clang-tidy $(if [ -f .clang-tidy ]; then echo '--config-file=.clang-tidy'; elif [ -f .config/.clang-tidy ]; then echo '--config-file=.config/.clang-tidy'; else echo '--config=\"" DEFAULT_CLANG_TIDY "\"'; fi) "
                                 "-- -std=c++17 -I src/ 2>&1", "clang-tidy"},
    {"code-scripts-syntax-lint",   "find scripts -name '*.sh' 2>/dev/null | xargs shellcheck 2>&1 || true", "shellcheck"},
    {"configuration-makefile-policy-validate", "if [ -f Makefile ]; then head -1 Makefile | grep -q '\\t' || true; fi", NULL},
    {"code-cpp-complexity-measure", "find src -name '*.c' -o -name '*.cpp' "
                                 "| xargs pmccabe 2>/dev/null "
                                 "| awk '$1 > 10 {found=1; print} END {if(found) exit 1}'", "pmccabe"},
    {"code-cpp-comment-measure",  "cloc --quiet --csv src/ 2>/dev/null "
                                 "| tail -1 | awk -F, '{pct=$4/($4+$5)*100; "
                                 "if(pct<20){printf \"%.0f%% < 20%%\\n\",pct; exit 1} "
                                 "else printf \"%.0f%% OK\\n\",pct}'", "cloc"},
    {"docs-cpp-syntax-validate",   "if [ -f Doxyfile ] || [ -f .config/Doxyfile ]; then "
                                 "  output=$(doxygen $(if [ -f Doxyfile ]; then echo 'Doxyfile'; else echo '.config/Doxyfile'; fi) 2>&1); "
                                 "  echo \"$output\" | grep 'warning:' | grep -v 'No output formats' && exit 1 || true; "
                                 "else echo 'skipped (no Doxyfile)'; fi", "doxygen"},
    {"code-generic-vulnerability-scan", "semgrep scan --config auto --error --quiet 2>&1", "semgrep"},
    {"code-generic-secrets-scan", "gitleaks detect --source . --log-level error --no-banner 2>&1", "gitleaks"},
    {NULL, NULL, NULL}
};

static const CheckDef FORMAT_DEFS[] = {
    {"code-cpp-syntax-format",   "find src -name '*.cpp' -o -name '*.c' -o -name '*.h' 2>/dev/null "
                                 "| xargs clang-format -i "
                                 "--style=\"$(if [ -f .clang-format ]; then echo 'file'; else echo '" DEFAULT_CLANG_FORMAT "'; fi)\"", "clang-format"},
    {"code-yaml-syntax-format",   "find . -name '*.yml' -o -name '*.yaml' "
                                 "| grep -v node_modules | grep -v .git "
                                 "| xargs sed -i '' 's/[[:space:]]*$//' 2>/dev/null || true", NULL},
    {"docs-markdown-syntax-format", "rumdl fmt $(if [ -f rumdl.toml ]; then echo '--config rumdl.toml'; elif [ -f .config/rumdl.toml ]; then echo '--config .config/rumdl.toml'; else echo '--disable MD013,MD033,MD036,MD041,MD046 --cache-dir .tmp/rumdl'; fi) . 2>&1", "rumdl"},
    {"code-scripts-syntax-format", "find scripts -name '*.sh' 2>/dev/null | xargs shfmt -i 2 -w 2>/dev/null || true", "shfmt"},
    {NULL, NULL, NULL}
};

/* Expand %s in template with config_dir */
static const char *expand_cmd(const char *tmpl, const char *config_dir, char *buf, size_t bufsz) {
    if (!strchr(tmpl, '%')) return tmpl;
    snprintf(buf, bufsz, tmpl, config_dir, config_dir, config_dir);
    return buf;
}
/* --- Utilities --- */

static bool has_file(const char *path) {
    return access(path, F_OK) == 0;
}

static bool has_target_in_makefile(const char *target) {
    if (!has_file("Makefile")) return false;
    char grep_cmd[256];
    /* Match target followed by optional whitespace and a colon. 
     * Supports both '^target:' and 'target :' formats. */
    snprintf(grep_cmd, sizeof(grep_cmd), "grep -qE '^%s[[:space:]]*:' Makefile 2>/dev/null", target);
    return cpm_exec(grep_cmd) == 0;
}

/* --- Output helpers --- */

static void print_result(const RunResult *r) {
    if (r->skipped)
        printf("  \033[33m⊘\033[0m %-20s skipped\n", r->name);
    else if (r->exit_code == 0)
        printf("  \033[32m✓\033[0m %-20s %.1fs\n", r->name, r->elapsed_sec);
    else if (r->warn_only)
        printf("  \033[33m⚠\033[0m %-20s warning\n", r->name);
    else
        printf("  \033[31m✗\033[0m %-20s FAILED\n", r->name);
}

static int run_defs(CpmConfig *cfg, const CheckDef *defs, const char *label, const char *filter) {
    int count = 0;
    for (int i = 0; defs[i].name; i++) {
        CpmCheck *c = cpm_check_find(cfg, defs[i].name);
        if (c && !c->enabled) continue;
        count++;
    }

    auto names = (const char **)calloc(count, sizeof(char *));
    auto commands = (const char **)calloc(count, sizeof(char *));
    auto cmd_bufs = (char (*)[1024])calloc(count, sizeof(char[1024]));
    auto warn = (bool *)calloc(count, sizeof(bool));
    int idx = 0;

    for (int i = 0; defs[i].name; i++) {
        CpmCheck *c = cpm_check_find(cfg, defs[i].name);
        if (c && !c->enabled) continue;
        names[idx] = defs[i].name;
        if (defs[i].tool && !cpm_has_tool(defs[i].tool)) {
            commands[idx] = NULL;
        } else if (c && c->command[0]) {
            commands[idx] = c->command;
        } else {
            commands[idx] = expand_cmd(defs[i].tmpl, cfg->config_dir,
                                       cmd_bufs[idx], 1024);
        }
        warn[idx] = c ? c->warn_only : false;
        idx++;
    }

    printf("\n%s (%d checks)\n", label, idx);
    RunSummary s = cpm_run_parallel(names, commands, warn, idx);

    for (int i = 0; i < s.count; i++)
        print_result(&s.results[i]);

    printf("\n  %d passed, %d failed, %d warned, %d skipped (%.1fs)\n",
           s.passed, s.failed, s.warned, s.skipped, s.total_sec);

    int rc = s.failed > 0 ? 1 : 0;
    free(s.results);
    free(names);
    free(commands);
    free(cmd_bufs);
    free(warn);
    return rc;
}

/* --- Commands --- */

static int cmd_init(void) {
    if (access(CPM_FILE, F_OK) == 0) {
        fprintf(stderr, "%s already exists.\n", CPM_FILE);
        return 1;
    }

    char name[128] = "", version[32] = "0.1.0", lang[16] = "cpp";
    char build[16] = "make", cfgdir[128] = ".config";

    /* Get project name from directory */
    char cwd[512];
    if (getcwd(cwd, sizeof(cwd))) {
        const char *base = strrchr(cwd, '/');
        snprintf(name, sizeof(name), "%s", base ? base + 1 : cwd);
    }

    /* --- Write cpm.toml --- */
    FILE *f = fopen(CPM_FILE, "w");
    if (!f) { perror("fopen"); return 1; }

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
        name, version, lang, build, cfgdir,
        strcmp(lang, "cpp") == 0 ? "llvm = \"19\"\n" : "");
    fclose(f);
    printf("  Created %s\n", CPM_FILE);
    printf("\nDone. Run 'cpm install' to install tools.\n");
    return 0;
}

static int cmd_new(int argc, char *argv[]) {
    if (argc < 3) {
        printf("Usage:\n"
               "  cpm new <project-name>   Create a new project\n"
               "  cpm new test <path>       Create a new test file\n"
               "  cpm new module <name>     Create a new module (cpp + hpp)\n");
        return 1;
    }

    const char *type = argv[2];
    if (strcmp(type, "test") == 0) {
        if (argc < 4) { printf("Missing test name.\n"); return 1; }
        char path[256];
        snprintf(path, sizeof(path), "src/%s_test.cpp", argv[3]);
        if (has_file(path)) { printf("  %s already exists.\n", path); return 1; }
        cpm_exec("mkdir -p src");
        FILE *f = fopen(path, "w");
        fprintf(f, "#include <iostream>\n\nint main() {\n    return 0;\n}\n");
        fclose(f);
        printf("  Created %s\n", path);
    } else if (strcmp(type, "module") == 0) {
        if (argc < 4) { printf("Missing module name.\n"); return 1; }
        cpm_exec("mkdir -p src");
        char cpp[256], hpp[256];
        snprintf(cpp, sizeof(cpp), "src/%s.cpp", argv[3]);
        snprintf(hpp, sizeof(hpp), "src/%s.hpp", argv[3]);
        if (!has_file(cpp)) {
            FILE *f = fopen(cpp, "w");
            fprintf(f, "#include \"%s.hpp\"\n", argv[3]);
            fclose(f);
            printf("  Created %s\n", cpp);
        }
        if (!has_file(hpp)) {
            FILE *f = fopen(hpp, "w");
            fprintf(f, "#pragma once\n\nclass %s {\n};\n", argv[3]);
            fclose(f);
            printf("  Created %s\n", hpp);
        }
    } else {
        /* New project */
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "mkdir -p %s", type);
        if (cpm_exec(cmd) != 0) return 1;
        if (chdir(type) != 0) return 1;
        cmd_init();
        cpm_exec("mkdir -p src");
        FILE *f = fopen("src/main.cpp", "w");
        fprintf(f, "#include <iostream>\n\nint main() {\n    std::cout << \"Hello from %s!\" << std::endl;\n    return 0;\n}\n", type);
        fclose(f);
        printf("  Created src/main.cpp\n");
    }
    return 0;
}

static int cmd_install(CpmConfig *cfg) {
    int rc = cpm_setup(cfg);
    /* Also copy cpm binary to PATH if running from a local build */
    char self[1024];
    ssize_t len = readlink("/proc/self/exe", self, sizeof(self) - 1);
    if (len < 0) {
        /* macOS: use argv[0] heuristic */
        printf("\nTo install cpm globally: sudo cp cpm %s\n", CPM_BIN);
    }
    return rc;
}

static int cmd_uninstall(int argc, char *argv[]) {
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
        printf("Note: tool uninstall not yet implemented. "
               "Use brew/apt to remove individual tools.\n");
    }
    return 0;
}

static int cmd_check(CpmConfig *cfg, const char *filter) {
    return run_defs(cfg, CHECK_DEFS, "cpm lint", filter);
}


static int cmd_format(CpmConfig *cfg) {
    return run_defs(cfg, FORMAT_DEFS, "cpm format", NULL);
}

static int cmd_build(CpmConfig *cfg) {

    /* If user explicitly requested cmake, or if there's no Makefile, prefer CMake */
    if (strcmp(cfg->build, "cmake") == 0 && has_file("CMakeLists.txt")) {
        printf("cpm build → cmake\n");
        if (cpm_exec("cmake -B build -S . 2>&1") != 0) return 1;
        return cpm_exec("cmake --build build 2>&1");
    }

    /* Priority 1: Makefile with explicit 'build' target */
    if (has_target_in_makefile("build")) {
        printf("cpm build → Makefile\n");
        return cpm_exec("make build 2>&1");
    }

    /* Priority 2: CMake fallback if CMakeLists.txt exists */
    if (has_file("CMakeLists.txt")) {
        printf("cpm build → CMakeLists.txt\n");
        if (cpm_exec("cmake -B build -S . 2>&1") != 0) return 1;
        return cpm_exec("cmake --build build 2>&1");
    }

    /* Priority 3: Makefile fallback (default goal) */
    if (has_file("Makefile")) {
        return cpm_exec("make 2>&1");
    }

    /* Priority 4: Generic compiler fallback (recursive find) */
    char cmd[1024];
    if (strcmp(cfg->lang, "cpp") == 0) {
        snprintf(cmd, sizeof(cmd),
                 "g++ -Wall -O2 -I src %s $(find src -name '*.cpp' ! -name '*_test.cpp' ! -name '*_main.cpp') -o %s %s 2>&1",
                 cfg->cflags, cfg->name, cfg->ldflags);
    } else {
        snprintf(cmd, sizeof(cmd),
                 "gcc -Wall -O2 -I src %s $(find src -name '*.c' ! -name '*_test.c' ! -name '*_main.c') -o %s %s 2>&1",
                 cfg->cflags, cfg->name, cfg->ldflags);
    }
    int rc = cpm_exec(cmd);

    /* Build extra binaries from [binaries] section */
    for (int i = 0; i < cfg->binary_count && rc == 0; i++) {
        const char *cc = strcmp(cfg->lang, "cpp") == 0 ? "g++" : "gcc";
        snprintf(cmd, sizeof(cmd),
                 "%s -Wall -O2 -I src %s %s -o %s %s 2>&1",
                 cc, cfg->cflags, cfg->binaries[i].source,
                 cfg->binaries[i].name, cfg->ldflags);
        rc = cpm_exec(cmd);
    }

    return rc;
}

static int cmd_test(CpmConfig *cfg) {
    (void)cfg;

    /* Priority 1: Makefile with explicit 'test' target */
    if (has_target_in_makefile("test")) {
        return cpm_exec("make test 2>&1");
    }

    /* Priority 2: CMake/CTest fallback */
    if (has_file("CMakeLists.txt") && has_file("build/CTestTestfile.cmake")) {
        return cpm_exec("cd build && ctest --output-on-failure 2>&1");
    }

    /* Priority 3: Common Makefile test targets */
    if (has_target_in_makefile("test-unit")) {
        return cpm_exec("make test-unit 2>&1");
    }
    if (has_target_in_makefile("check")) {
        return cpm_exec("make check 2>&1");
    }

    /* Priority 4: Generic test fallback - compile and run test files */
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

static int cmd_coverage(CpmConfig *cfg);

static int cmd_run(CpmConfig *cfg) {
    int rc = cmd_build(cfg);
    if (rc != 0) return rc;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "./%s", cfg->name);
    printf("cpm run → %s\n", cmd);
    return cpm_exec(cmd);
}

static int cmd_clean(CpmConfig *cfg) {
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

static int cmd_check_gate(CpmConfig *cfg, const char *tier) {
    bool fast = tier && strcmp(tier, "--fast") == 0;
    bool full = tier && strcmp(tier, "--full") == 0;
    int rc = 0;

    /* Tier 1 (--fast): format + build */
    printf("=== Tier 1: format + build ===\n");
    rc |= cmd_format(cfg);
    rc |= cmd_build(cfg);
    if (fast) return rc;

    /* Tier 2 (default): + lint + test */
    printf("\n=== Tier 2: lint + test ===\n");
    rc |= run_defs(cfg, CHECK_DEFS, "cpm lint", NULL);
    rc |= cmd_test(cfg);
    if (!full) return rc;

    /* Tier 3 (--full): + coverage + sast */
    printf("\n=== Tier 3: coverage + sast ===\n");
    rc |= cmd_coverage(cfg);
    return rc;
}

static int cmd_coverage(CpmConfig *cfg) {
    printf("cpm coverage\n");

    /* Priority 1: Makefile coverage target */
    if (has_target_in_makefile("coverage")) return cpm_exec("make coverage 2>&1");

    /* Priority 2: generic gcov fallback */
    char cmd[1024];
    const char *cc = strcmp(cfg->lang, "cpp") == 0 ? "g++" : "gcc";
    const char *ext = strcmp(cfg->lang, "cpp") == 0 ? "cpp" : "c";
    snprintf(cmd, sizeof(cmd),
             "mkdir -p .tmp/cov && "
             "%s -Wall -O2 -I src --coverage "
             "$(find src tests -name '*.%s' ! -name 'main.%s' 2>/dev/null) "
             "-o .tmp/cov/cov_bin 2>&1 && .tmp/cov/cov_bin && "
             "LCOV_OPTS='--ignore-errors inconsistent,inconsistent,unsupported,unsupported,corrupt,corrupt,unused,unused' && "
             "lcov --capture --directory . --output-file .tmp/cov/coverage.info --quiet $LCOV_OPTS 2>&1 && "
             "lcov --remove .tmp/cov/coverage.info '/usr/*' --output-file .tmp/cov/coverage.info --quiet $LCOV_OPTS 2>&1 && "
             "lcov --summary .tmp/cov/coverage.info $LCOV_OPTS; "
             "rm -f *.gcda *.gcno .tmp/cov/cov_bin .tmp/cov/*.gcda .tmp/cov/*.gcno",
             cc, ext, ext);
    return cpm_exec(cmd);
}

static int cmd_eject(CpmConfig *cfg) {
    printf("Ejecting configuration and build system boilerplate...\n");

    const char *cfgdir = cfg->config_dir;
    if (strcmp(cfgdir, ".") != 0) {
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "mkdir -p %s", cfgdir);
        cpm_exec(cmd);
    }

    char path[256];
    FILE *f;

    /* .clang-format */
    snprintf(path, sizeof(path), "%s/.clang-format", cfgdir);
    if (!has_file(path)) {
        f = fopen(path, "w");
        fprintf(f, "BasedOnStyle: Google\nIndentWidth: 2\nColumnLimit: 140\nPointerAlignment: Left\n");
        fclose(f); printf("  Created %s\n", path);
    }

    /* .clang-tidy */
    snprintf(path, sizeof(path), "%s/.clang-tidy", cfgdir);
    if (!has_file(path)) {
        f = fopen(path, "w");
        fprintf(f, "Checks: 'readability-*,bugprone-*,misc-*'\nCheckOptions:\n  - key: readability-function-size.LineThreshold\n    value: '40'\n");
        fclose(f); printf("  Created %s\n", path);
    }

    /* yamllint.yml */
    snprintf(path, sizeof(path), "%s/yamllint.yml", cfgdir);
    if (!has_file(path)) {
        f = fopen(path, "w");
        fprintf(f, "extends: default\nrules:\n  line-length: {max: 140}\n  document-start: disable\n");
        fclose(f); printf("  Created %s\n", path);
    }

    /* rumdl.toml */
    snprintf(path, sizeof(path), "%s/rumdl.toml", cfgdir);
    if (!has_file(path)) {
        f = fopen(path, "w");
        fprintf(f, "[global]\nexclude = [\"node_modules\"]\nrespect-gitignore = true\n");
        fclose(f); printf("  Created %s\n", path);
    }

    /* Doxyfile */
    snprintf(path, sizeof(path), "%s/Doxyfile", cfgdir);
    if (!has_file(path)) {
        f = fopen(path, "w");
        fprintf(f, "PROJECT_NAME = %s\nINPUT = src\nRECURSIVE = YES\nGENERATE_HTML = NO\nGENERATE_LATEX = NO\n", cfg->name);
        fclose(f); printf("  Created %s\n", path);
    }

    if (!has_file("Makefile")) {
        FILE *f = fopen("Makefile", "w");
        if (f) {
            fprintf(f,
                "CXX      = g++\n"
                "CXXFLAGS = -Wall -Wextra -std=c++17 -O2 -I src\n"
                "BINARY   = %s\n"
                "SRCS     = $(wildcard src/*.cpp)\n"
                "\n"
                ".PHONY: all build clean test\n"
                "\n"
                "all: build\n"
                "\n"
                "build: $(BINARY)\n"
                "\n"
                "$(BINARY): $(SRCS)\n"
                "\t$(CXX) $(CXXFLAGS) -o $@ $(SRCS)\n"
                "\n"
                "test:\n"
                "\t@find src -name '*_test.cpp' | xargs -I{} $(CXX) $(CXXFLAGS) {} -o test_bin && ./test_bin && rm test_bin\n"
                "\n"
                "clean:\n"
                "\trm -f $(BINARY) test_bin\n",
                cfg->name);
            fclose(f);
            printf("  Created Makefile\n");
        }
    } else {
        printf("  Makefile already exists, skipping.\n");
    }

    if (!has_file("CMakeLists.txt")) {
        FILE *f = fopen("CMakeLists.txt", "w");
        if (f) {
            fprintf(f,
                "cmake_minimum_required(VERSION 3.15)\n"
                "project(%s VERSION %s)\n"
                "\n"
                "set(CMAKE_CXX_STANDARD 17)\n"
                "set(CMAKE_CXX_STANDARD_REQUIRED ON)\n"
                "\n"
                "include_directories(src)\n"
                "\n"
                "file(GLOB_RECURSE SOURCES \"src/*.cpp\")\n"
                "add_executable(${PROJECT_NAME} ${SOURCES})\n"
                "\n"
                "enable_testing()\n"
                "file(GLOB_RECURSE TEST_SOURCES \"src/*_test.cpp\")\n"
                "foreach(test_src ${TEST_SOURCES})\n"
                "    get_filename_component(test_name ${test_src} NAME_WE)\n"
                "    add_executable(${test_name} ${test_src})\n"
                "    add_test(NAME ${test_name} COMMAND ${test_name})\n"
                "endforeach()\n",
                cfg->name, cfg->version);
            fclose(f);
            printf("  Created CMakeLists.txt\n");
        }
    } else {
        printf("  CMakeLists.txt already exists, skipping.\n");
    }

    return 0;
}

static int cmd_hook(CpmConfig *cfg) {
    printf("Installing git hooks...\n");
    if (cfg->hook_pre_commit)
        cpm_exec("cp scripts/git/pre-commit.sh .git/hooks/pre-commit "
                 "&& chmod +x .git/hooks/pre-commit");
    if (cfg->hook_pre_push)
        cpm_exec("cp scripts/git/pre-push.sh .git/hooks/pre-push "
                 "&& chmod +x .git/hooks/pre-push");
    if (cfg->hook_commit_msg)
        cpm_exec("cp scripts/git/commit-msg.sh .git/hooks/commit-msg "
                 "&& chmod +x .git/hooks/commit-msg");
    printf("Done.\n");
    return 0;
}

static int cmd_unhook(void) {
    printf("Removing git hooks...\n");
    cpm_exec("rm -f .git/hooks/pre-commit .git/hooks/pre-push .git/hooks/commit-msg");
    printf("Done.\n");
    return 0;
}

static int cmd_bump(CpmConfig *cfg, const char *part) {
    if (!part || (strcmp(part, "major") != 0 &&
                  strcmp(part, "minor") != 0 &&
                  strcmp(part, "patch") != 0)) {
        fprintf(stderr, "Usage: cpm bump <major|minor|patch>\n");
        return 1;
    }

    int major = 0, minor = 0, patch = 0;
    sscanf(cfg->version, "%d.%d.%d", &major, &minor, &patch);

    if (strcmp(part, "major") == 0)      { major++; minor = 0; patch = 0; }
    else if (strcmp(part, "minor") == 0) { minor++; patch = 0; }
    else                                 { patch++; }

    char newver[32];
    snprintf(newver, sizeof(newver), "%d.%d.%d", major, minor, patch);

    /* Write back to cpm.toml */
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
             "sed -i '' 's/^version = \".*\"/version = \"%s\"/' %s",
             newver, CPM_FILE);
    cpm_exec(cmd);

    printf("%s → %s\n", cfg->version, newver);
    return 0;
}

static int cmd_audit(CpmConfig *cfg) {
    printf("cpm audit — checking tool versions\n\n");
    /* TODO: compare installed versions against cpm.toml pinned versions */
    cpm_versions(cfg);
    printf("\nNote: version mismatch detection coming soon.\n");
    return 0;
}

static int cmd_get(CpmConfig *cfg, const char *key) {
    if (!key) {
        /* List all settings */
        printf("[project]\n");
        printf("  name    = %s\n", cfg->name);
        printf("  version = %s\n", cfg->version);
        printf("  lang    = %s\n", cfg->lang);
        printf("  build   = %s\n", cfg->build);
        printf("\n[checks] (%d)\n", cfg->check_count);
        for (int i = 0; i < cfg->check_count; i++) {
            CpmCheck *c = &cfg->checks[i];
            printf("  %-20s %s%s\n", c->name,
                   c->enabled ? "on" : "off",
                   c->warn_only ? " (warn)" : "");
        }
        printf("\n[hooks]\n");
        printf("  pre-commit = %s\n", cfg->hook_pre_commit ? "true" : "false");
        printf("  pre-push   = %s\n", cfg->hook_pre_push ? "true" : "false");
        printf("  commit-msg = %s\n", cfg->hook_commit_msg ? "true" : "false");
        return 0;
    }

    /* Get specific key */
    if (strcmp(key, "name") == 0)         printf("%s\n", cfg->name);
    else if (strcmp(key, "version") == 0) printf("%s\n", cfg->version);
    else if (strcmp(key, "lang") == 0)    printf("%s\n", cfg->lang);
    else if (strcmp(key, "build") == 0)   printf("%s\n", cfg->build);
    else {
        CpmCheck *c = cpm_check_find(cfg, key);
        if (c) printf("%s = %s%s\n", c->name,
                       c->enabled ? "true" : "false",
                       c->warn_only ? " (warn-only)" : "");
        else { fprintf(stderr, "Unknown key: %s\n", key); return 1; }
    }
    return 0;
}

static int cmd_set(const char *key, const char *val) {
    if (!key || !val) {
        fprintf(stderr, "Usage: cpm set <key> <value>\n");
        return 1;
    }
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
             "sed -i '' 's/^%s = .*/%s = %s/' %s", key, key, val, CPM_FILE);
    cpm_exec(cmd);
    printf("%s = %s\n", key, val);
    return 0;
}

/* --- Usage --- */

static void usage(void) {
    printf("cpm %s — C Project Manager\n\n"
           "Usage: cpm <command> [options]\n\n"
           "Commands:\n"
           "  new <name>       Create a new project (Convention: <domain>-<flavor>-<intent>-<method>)\n"
           "                   Example: code-cpp-vulnerability-scan\n"
           "  new test <name>  Add a new test file (e.g. 'cpm new test parser')\n"
           "  new module <name> Add a module (src/name.cpp + src/name.hpp)\n"
           "  init             Create a new cpm.toml in current directory\n"
           "  install          Install tools from cpm.toml\n"
           "  uninstall [--all] Remove cpm from PATH (--all: tools too)\n"
           "  check [--fast|--full] Run quality gate (tiered)\n"
           "  lint             Run all lint checks\n"
           "  format           Auto-format all files\n"
           "  build            Build the project\n"
           "  run              Build and run the project\n"
           "  test             Run tests\n"
           "  coverage         Build with coverage and report\n"
           "  clean            Remove build artifacts\n"
           "  eject            Generate Makefile and CMakeLists.txt\n"
           "  audit            Check tool versions against cpm.toml\n"
           "  bump <part>      Bump version (major|minor|patch)\n"
           "  hook             Install git hooks\n"
           "  unhook           Remove git hooks\n"
           "  get [key]        Show config (all or specific key)\n"
           "  set <key> <val>  Update config value\n"
           "  version          Show tool versions\n"
           "  help             Show this help\n",
           CPM_VERSION);
}

/* --- Main --- */

int main(int argc, char *argv[]) {
    if (argc < 2) { usage(); return 0; }

    const char *cmd = argv[1];
    if (strcmp(cmd, "help") == 0 || strcmp(cmd, "-h") == 0 ||
        strcmp(cmd, "--help") == 0) {
        usage();
        return 0;
    }

    /* init and new don't need an existing cpm.toml */
    if (strcmp(cmd, "init") == 0) return cmd_init();
    if (strcmp(cmd, "new") == 0)  return cmd_new(argc, argv);

    CpmConfig cfg;
    if (cpm_toml_parse(CPM_FILE, &cfg) != 0) {
        fprintf(stderr, "Error: %s not found. Run 'cpm init' to create one.\n",
                CPM_FILE);
        return 1;
    }

    if (strcmp(cmd, "install") == 0)        return cmd_install(&cfg);
    else if (strcmp(cmd, "uninstall") == 0) return cmd_uninstall(argc, argv);
    else if (strcmp(cmd, "check") == 0)     return cmd_check_gate(&cfg, argc > 2 ? argv[2] : NULL);
    else if (strcmp(cmd, "lint") == 0)      return cmd_check(&cfg, argc > 2 ? argv[2] : NULL);
    else if (strcmp(cmd, "format") == 0)    return cmd_format(&cfg);
    else if (strcmp(cmd, "build") == 0)     return cmd_build(&cfg);
    else if (strcmp(cmd, "run") == 0)       return cmd_run(&cfg);
    else if (strcmp(cmd, "test") == 0)      return cmd_test(&cfg);
    else if (strcmp(cmd, "coverage") == 0)  return cmd_coverage(&cfg);
    else if (strcmp(cmd, "clean") == 0)     return cmd_clean(&cfg);
    else if (strcmp(cmd, "eject") == 0)     return cmd_eject(&cfg);
    else if (strcmp(cmd, "audit") == 0)     return cmd_audit(&cfg);
    else if (strcmp(cmd, "bump") == 0)      return cmd_bump(&cfg, argc > 2 ? argv[2] : NULL);
    else if (strcmp(cmd, "hook") == 0)      return cmd_hook(&cfg);
    else if (strcmp(cmd, "unhook") == 0)    return cmd_unhook();
    else if (strcmp(cmd, "get") == 0)       return cmd_get(&cfg, argc > 2 ? argv[2] : NULL);
    else if (strcmp(cmd, "set") == 0)       return cmd_set(argc > 2 ? argv[2] : NULL,
                                                           argc > 3 ? argv[3] : NULL);
    else if (strcmp(cmd, "version") == 0)   { cpm_versions(&cfg); return 0; }
    else {
        fprintf(stderr, "Unknown command: %s\n", cmd);
        usage();
        return 1;
    }
}
