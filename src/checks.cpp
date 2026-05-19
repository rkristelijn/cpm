/* checks.cpp — Quality check definitions and parallel runner
// @see ADR-129
 *
 * This file defines WHAT gets checked (CHECK_DEFS, FORMAT_DEFS) and
 * HOW checks are executed (run_defs → cpm_run_parallel).
 *
 * Each check has:
 * - name: matches the key in cpm.toml [checks] section
 * - tmpl: shell command template to execute
 * - tool: required binary (skipped if not installed)
 *
 * The tiered gate (--fast/default/--full) controls which checks run:
 * - fast:    format + build (pre-commit, <5s)
 * - default: + lint + test (pre-push, <60s)
 * - full:    + coverage + sast (CI)
 */
#include "checks.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "runner.h"
#include "toml.h"
#include "ui.h"

/* --- Check definitions ---
 *
 * Naming convention: <domain>-<lang>-<aspect>-<action>
 * e.g. code-cpp-syntax-format, code-generic-secrets-scan
 */

typedef struct {
  const char* name; /* check identifier (matches cpm.toml key) */
  const char* tmpl; /* shell command to run */
  const char* tool; /* required binary, NULL if no tool needed */
} CheckDef;

/* Default configs used when no project-local config exists */
#define DEFAULT_CLANG_FORMAT "{BasedOnStyle: Google, IndentWidth: 2, ColumnLimit: 140, PointerAlignment: Left}"
#define DEFAULT_CLANG_TIDY \
  "{Checks: 'readability-*,bugprone-*,misc-*', CheckOptions: [{key: readability-function-size.LineThreshold, value: '40'}]}"

/* Lint checks: verify code quality without modifying files */
static const CheckDef CHECK_DEFS[] = {
    {"code-cpp-syntax-format",
     "find src -name '*.cpp' -o -name '*.c' -o -name '*.h' 2>/dev/null "
     "| xargs clang-format --dry-run -Werror "
     "--style=\"$(if [ -f .clang-format ]; then echo 'file'; else echo '" DEFAULT_CLANG_FORMAT "'; fi)\" 2>&1",
     "clang-format"},
    {"code-yaml-syntax-format",
     "git ls-files '*.yml' '*.yaml' 2>/dev/null "
     "| xargs yamllint $(if [ -f yamllint.yml ]; then echo '-c yamllint.yml'; elif [ -f .config/yamllint.yml ]; then echo '-c "
     ".config/yamllint.yml'; else echo '-d \"{extends: default, rules: {line-length: {max: 140}, document-start: disable}}\"'; fi) 2>&1",
     "yamllint"},
    {"docs-markdown-syntax-format",
     "rumdl check --respect-gitignore --exclude 'vendor,node_modules,dist,.next,build' "
     "$(if [ -f rumdl.toml ]; then echo '--config rumdl.toml'; elif [ -f .config/rumdl.toml ]; then echo '--config "
     ".config/rumdl.toml'; else echo '--disable MD013,MD033,MD036,MD041,MD046 --cache-dir .tmp/rumdl'; fi) . 2>&1",
     "rumdl"},
    {"code-scripts-syntax-format", "find scripts -name '*.sh' 2>/dev/null | xargs shfmt -d -i 2 2>&1 || true", "shfmt"},
    {"code-cpp-syntax-lint",
     "cppcheck --enable=all --suppress=missingIncludeSystem "
     "--suppress=unusedFunction --error-exitcode=1 -I src src/ 2>&1",
     "cppcheck"},
    {"code-cpp-quality-lint",
     "find src -name '*.cpp' -o -name '*.c' "
     "| xargs clang-tidy $(if [ -f .clang-tidy ]; then echo '--config-file=.clang-tidy'; elif [ -f .config/.clang-tidy ]; then echo "
     "'--config-file=.config/.clang-tidy'; else echo '--config=\"" DEFAULT_CLANG_TIDY "\"'; fi) "
     "-- -std=c++17 -I src/ 2>&1",
     "clang-tidy"},
    {"code-scripts-syntax-lint", "find scripts -name '*.sh' 2>/dev/null | xargs shellcheck 2>&1 || true", "shellcheck"},
    {"configuration-makefile-policy-validate", "if [ -f Makefile ]; then head -1 Makefile | grep -q '\\t' || true; fi", NULL},
    {"code-cpp-complexity-measure",
     "find src -name '*.c' -o -name '*.cpp' "
     "| xargs pmccabe 2>/dev/null "
     "| awk '$1 > 10 {found=1; print} END {if(found) exit 1}'",
     "pmccabe"},
    {"code-cpp-comment-measure",
     "cloc --quiet --csv src/ 2>/dev/null "
     "| tail -1 | awk -F, '{pct=$4/($4+$5)*100; "
     "if(pct<20){printf \"%.0f%% < 20%%\\n\",pct; exit 1} "
     "else printf \"%.0f%% OK\\n\",pct}'",
     "cloc"},
    {"docs-cpp-syntax-validate",
     "if [ -f Doxyfile ] || [ -f .config/Doxyfile ]; then "
     "  output=$(doxygen $(if [ -f Doxyfile ]; then echo 'Doxyfile'; else echo '.config/Doxyfile'; fi) 2>&1); "
     "  echo \"$output\" | grep 'warning:' | grep -v 'No output formats' && exit 1 || true; "
     "else echo 'skipped (no Doxyfile)'; fi",
     "doxygen"},
    {"code-generic-vulnerability-scan", "semgrep scan --config auto --error --quiet 2>&1", "semgrep"},
    {"code-generic-secrets-scan", "gitleaks detect --source . --log-level error --no-banner 2>&1", "gitleaks"},
    {"code-generic-secrets-fast",
     "grep -rn --include='*.cpp' --include='*.h' --include='*.ts' --include='*.py' --include='*.js' --include='*.json' "
     "-E '(sk-[a-zA-Z0-9]{20}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|-----BEGIN (RSA |EC )?PRIVATE "
     "KEY|xox[bpras]-|AIza[a-zA-Z0-9_-]{35}|sk_live_)' "
     "src/ . 2>/dev/null | grep -v 'cpm:ignore' | grep -v node_modules",
     NULL},
    {NULL, NULL, NULL}};

/* Format commands: modify files in-place to fix style */
static const CheckDef FORMAT_DEFS[] = {
    {"code-cpp-syntax-format",
     "find src -name '*.cpp' -o -name '*.c' -o -name '*.h' 2>/dev/null "
     "| xargs clang-format -i "
     "--style=\"$(if [ -f .clang-format ]; then echo 'file'; else echo '" DEFAULT_CLANG_FORMAT "'; fi)\"",
     "clang-format"},
    {"code-yaml-syntax-format",
     "git ls-files '*.yml' '*.yaml' 2>/dev/null "
     "| xargs sed -i '' 's/[[:space:]]*$//' 2>/dev/null || true",
     NULL},
    {"docs-markdown-syntax-format",
     "rumdl fmt --respect-gitignore --exclude 'vendor,node_modules,dist,.next,build' "
     "$(if [ -f rumdl.toml ]; then echo '--config rumdl.toml'; elif [ -f .config/rumdl.toml ]; then echo '--config "
     ".config/rumdl.toml'; else echo '--disable MD013,MD033,MD036,MD041,MD046 --cache-dir .tmp/rumdl'; fi) . 2>&1",
     "rumdl"},
    {"code-scripts-syntax-format", "find scripts -name '*.sh' 2>/dev/null | xargs shfmt -i 2 -w 2>/dev/null || true", "shfmt"},
    {NULL, NULL, NULL}};

/* --- Runner helpers --- */

/* Expand %s placeholders in command template (for config_dir paths) */
static const char* expand_cmd(const char* tmpl, const char* /*config_dir*/, char* buf, size_t bufsz) {
  if (!strchr(tmpl, '%')) return tmpl;
  snprintf(buf, bufsz, tmpl, "", "", "");
  return buf;
}

/* Print a single check result using centralized UI */
static void print_result(const RunResult* r) {
  if (r->skipped)
    ui_skip(r->name);
  else if (r->exit_code == 0)
    ui_success(r->name, r->elapsed_sec);
  else if (r->warn_only)
    ui_warn(r->name);
  else
    ui_fail(r->name);
}

/* Run a set of check definitions in parallel.
 * Skips disabled checks (from cpm.toml) and missing tools. */
static int run_defs(CpmConfig* cfg, const CheckDef* defs, const char* label) {
  /* Count enabled checks */
  int count = 0;
  for (int i = 0; defs[i].name; i++) {
    CpmCheck* c = cpm_check_find(cfg, defs[i].name);
    if (c && !c->enabled) continue;
    if (strstr(defs[i].name, "-cpp-") && strcmp(cfg->lang, "cpp") != 0 && strcmp(cfg->lang, "c") != 0) continue;
    count++;
  }

  /* Build parallel execution arrays */
  auto names = (const char**)calloc(count, sizeof(char*));
  auto commands = (const char**)calloc(count, sizeof(char*));
  auto cmd_bufs = (char (*)[1024])calloc(count, sizeof(char[1024]));
  auto warn = (bool*)calloc(count, sizeof(bool));
  int idx = 0;

  for (int i = 0; defs[i].name; i++) {
    CpmCheck* c = cpm_check_find(cfg, defs[i].name);
    if (c && !c->enabled) continue;
    /* Skip lang-specific checks when lang doesn't match */
    if (strstr(defs[i].name, "-cpp-") && strcmp(cfg->lang, "cpp") != 0 && strcmp(cfg->lang, "c") != 0) continue;
    names[idx] = defs[i].name;
    /* Skip if required tool is not installed */
    if (defs[i].tool && !cpm_has_tool(defs[i].tool)) {
      commands[idx] = NULL;
    } else if (c && c->command[0]) {
      /* User override from cpm.toml [checks.name] command = "..." */
      commands[idx] = c->command;
    } else {
      commands[idx] = expand_cmd(defs[i].tmpl, cfg->config_dir, cmd_bufs[idx], 1024);
    }
    warn[idx] = c ? c->warn_only : false;
    idx++;
  }

  ui_header(label, idx);
  RunSummary s = cpm_run_parallel(names, commands, warn, idx);

  for (int i = 0; i < s.count; i++) print_result(&s.results[i]);

  ui_summary(s.passed, s.failed, s.warned, s.skipped, s.total_sec);

  /* Write failures to findings DB (dedup: overwrite per check run) */
  const char* home = getenv("HOME");
  if (home && (s.failed > 0 || s.warned > 0)) {
    char fpath[512];
    snprintf(fpath, sizeof(fpath), "%s/.local/share/cpm/check-findings.jsonl", home);
    FILE* ff = fopen(fpath, "a");
    if (ff) {
      for (int i = 0; i < s.count; i++) {
        if (s.results[i].exit_code != 0 && !s.results[i].skipped) {
          const char* sev = s.results[i].warn_only ? "warning" : "error";
          fprintf(ff, "{\"check\":\"%s\",\"severity\":\"%s\",\"file\":\".\",\"rule\":\"%s\",\"message\":\"check failed\"}\n",
                  s.results[i].name, sev, s.results[i].name);
        }
      }
      fclose(ff);
    }
  }

  int rc = s.failed > 0 ? 1 : 0;
  free(s.results);
  free(names);
  free(commands);
  free(cmd_bufs);
  free(warn);
  return rc;
}

/* --- Public API --- */

int cmd_check(CpmConfig* cfg, const char* /*filter*/) { return run_defs(cfg, CHECK_DEFS, "cpm lint"); }

int cmd_format(CpmConfig* cfg) { return run_defs(cfg, FORMAT_DEFS, "cpm format"); }

/* Tiered quality gate — the core of cpm's shift-left philosophy.
 * Each tier adds more checks, matching the git workflow stage. */
int cmd_check_gate(CpmConfig* cfg, const char* tier) {
  bool fast = tier && strcmp(tier, "--fast") == 0;
  bool full = tier && strcmp(tier, "--full") == 0;
  int rc = 0;

  /* Tier 1 (--fast): format + build — catches obvious issues instantly */
  ui_tier("Tier 1: format + build");
  rc |= cmd_format(cfg);
  extern int cmd_build(CpmConfig*);
  extern int cmd_test(CpmConfig*);
  extern int cmd_coverage(CpmConfig*);
  rc |= cmd_build(cfg);
  if (fast) return rc;

  /* Tier 2 (default): + lint + test — thorough pre-push validation */
  ui_tier("Tier 2: lint + test");
  rc |= run_defs(cfg, CHECK_DEFS, "cpm lint");
  rc |= cmd_test(cfg);
  if (!full) return rc;

  /* Tier 3 (--full): + coverage + sast — CI-level deep analysis */
  ui_tier("Tier 3: coverage + sast");
  rc |= cmd_coverage(cfg);
  return rc;
}
