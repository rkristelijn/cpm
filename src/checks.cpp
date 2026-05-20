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
    {"docs-prose-style-lint", "if [ -f .vale.ini ]; then vale docs/ README.md 2>&1; else echo 'skip: no .vale.ini'; fi || true", "vale"},
    {"docs-prose-inclusivity-lint",
     "if command -v alex >/dev/null 2>&1; then alex docs/ README.md CONTRIBUTING.md 2>&1; "
     "elif command -v npx >/dev/null 2>&1; then npx --yes alex docs/ README.md CONTRIBUTING.md 2>&1; "
     "else echo 'skip: alex not found (brew install alex)'; fi || true",
     NULL},
    {"docs-prose-spelling-check",
     "if command -v cspell >/dev/null 2>&1; then cspell lint --no-progress --no-summary --gitignore 'docs/**/*.md' 'README.md' 2>&1; "
     "elif command -v npx >/dev/null 2>&1; then npx --yes cspell lint --no-progress --no-summary --gitignore 'docs/**/*.md' 'README.md' "
     "2>&1; "
     "else echo 'skip: cspell not found (brew install cspell)'; fi || true",
     NULL},
    {"docs-links-validate", "lychee --no-progress --exclude-loopback docs/ README.md 2>&1 || true", "lychee"},
    /* SCA: dependency vulnerability + outdated + license checks */
    {"deps-npm-audit",
     "if [ -f package-lock.json ]; then npm audit --omit=dev 2>&1; "
     "elif [ -f pnpm-lock.yaml ]; then pnpm audit --prod 2>&1; "
     "elif [ -f yarn.lock ]; then yarn npm audit --environment production 2>&1; fi || true",
     NULL},
    {"deps-npm-outdated", "if [ -f package.json ]; then npm outdated --long 2>&1; fi || true", NULL},
    {"deps-npm-license",
     "if command -v license-checker >/dev/null 2>&1 && [ -f package.json ]; then "
     "license-checker --failOn 'GPL-3.0;AGPL-3.0' --summary 2>&1; "
     "elif command -v npx >/dev/null 2>&1 && [ -f package.json ]; then "
     "npx --yes license-checker --failOn 'GPL-3.0;AGPL-3.0' --summary 2>&1; fi || true",
     NULL},
    {"deps-python-audit",
     "if [ -f requirements.txt ] || [ -f pyproject.toml ]; then "
     "if command -v pip-audit >/dev/null 2>&1; then pip-audit 2>&1; "
     "elif command -v safety >/dev/null 2>&1; then safety check 2>&1; fi; fi || true",
     NULL},
    {"deps-go-vuln",
     "if [ -f go.mod ]; then "
     "if command -v govulncheck >/dev/null 2>&1; then govulncheck ./... 2>&1; "
     "else echo 'skip: govulncheck not found (go install golang.org/x/vuln/cmd/govulncheck@latest)'; fi; fi || true",
     NULL},
    {"deps-cargo-audit", "if [ -f Cargo.toml ] && command -v cargo-audit >/dev/null 2>&1; then cargo audit 2>&1; fi || true", NULL},
    {"deps-java-audit",
     "if [ -f pom.xml ] && command -v mvn >/dev/null 2>&1; then "
     "mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7 -q 2>&1; fi || true",
     NULL},
    {"deps-php-audit", "if [ -f composer.lock ] && command -v composer >/dev/null 2>&1; then composer audit 2>&1; fi || true", NULL},
    {"deps-java-license",
     "if [ -f pom.xml ] && command -v mvn >/dev/null 2>&1; then "
     "mvn license:third-party-report -q 2>&1 | grep -iE 'GPL-3|AGPL' && exit 1 || true; fi || true",
     NULL},
    {"deps-dotnet-audit",
     "if ls *.csproj *.sln 2>/dev/null | head -1 >/dev/null && command -v dotnet >/dev/null 2>&1; then "
     "dotnet list package --vulnerable 2>&1; fi || true",
     NULL},
    {"deps-dotnet-outdated",
     "if ls *.csproj *.sln 2>/dev/null | head -1 >/dev/null && command -v dotnet >/dev/null 2>&1; then "
     "dotnet list package --outdated 2>&1; fi || true",
     NULL},
    {"iac-terraform-lint", "if [ -f main.tf ] && command -v tflint >/dev/null 2>&1; then tflint --recursive 2>&1; fi || true", NULL},
    {"iac-terraform-security",
     "if [ -f main.tf ]; then "
     "if command -v tfsec >/dev/null 2>&1; then tfsec . --soft-fail 2>&1; "
     "elif command -v trivy >/dev/null 2>&1; then trivy config . 2>&1; fi; fi || true",
     NULL},
    {"deps-ruby-audit",
     "if [ -f Gemfile.lock ] && command -v bundle-audit >/dev/null 2>&1; then bundle-audit check --update 2>&1; fi || true", NULL},
    {"deps-ruby-outdated", "if [ -f Gemfile.lock ] && command -v bundle >/dev/null 2>&1; then bundle outdated --strict 2>&1; fi || true",
     NULL},
    {"deps-dart-outdated", "if [ -f pubspec.yaml ] && command -v dart >/dev/null 2>&1; then dart pub outdated 2>&1; fi || true", NULL},
    {"code-dart-analyze",
     "if [ -f pubspec.yaml ] && command -v dart >/dev/null 2>&1; then dart analyze 2>&1; "
     "elif [ -f pubspec.yaml ] && command -v flutter >/dev/null 2>&1; then flutter analyze 2>&1; fi || true",
     NULL},
    /* Phase 1: fill the matrix */
    {"deps-python-outdated",
     "if [ -f requirements.txt ] || [ -f pyproject.toml ]; then "
     "if command -v pip >/dev/null 2>&1; then pip list --outdated --format=columns 2>&1 | head -20; fi; fi || true",
     NULL},
    {"deps-python-license",
     "if command -v pip-licenses >/dev/null 2>&1 && ([ -f requirements.txt ] || [ -f pyproject.toml ]); then "
     "pip-licenses --fail-on='GPL-3.0-only;AGPL-3.0-only' --summary 2>&1; fi || true",
     NULL},
    {"code-python-lint",
     "if ([ -f pyproject.toml ] || [ -f requirements.txt ]) && command -v ruff >/dev/null 2>&1; then ruff check . 2>&1; fi || true", NULL},
    {"deps-java-outdated",
     "if [ -f pom.xml ] && command -v mvn >/dev/null 2>&1; then "
     "mvn versions:display-dependency-updates -q 2>&1 | grep '\\->' | head -20; fi || true",
     NULL},
    {"deps-go-outdated",
     "if [ -f go.mod ] && command -v go >/dev/null 2>&1; then go list -m -u all 2>&1 | grep '\\[' | head -20; fi || true", NULL},
    {"deps-go-license",
     "if [ -f go.mod ] && command -v go-licenses >/dev/null 2>&1; then "
     "go-licenses check . 2>&1 | grep -iE 'GPL-3|AGPL' && exit 1 || true; fi || true",
     NULL},
    {"deps-rust-outdated", "if [ -f Cargo.toml ] && command -v cargo-outdated >/dev/null 2>&1; then cargo outdated 2>&1; fi || true", NULL},
    {"deps-rust-license",
     "if [ -f Cargo.toml ] && command -v cargo-license >/dev/null 2>&1; then "
     "cargo-license 2>&1 | grep -iE 'GPL-3|AGPL' && exit 1 || true; fi || true",
     NULL},
    {"deps-ruby-license", "if [ -f Gemfile.lock ] && command -v license_finder >/dev/null 2>&1; then license_finder 2>&1; fi || true",
     NULL},
    {"deps-php-outdated",
     "if [ -f composer.lock ] && command -v composer >/dev/null 2>&1; then composer outdated --direct 2>&1 | head -20; fi || true", NULL},
    /* Supply chain: lockfile integrity + pinned actions */
    {"supply-chain-lockfile-sync",
     "if [ -f package.json ] && [ -f package-lock.json ]; then "
     "npm ls --all 2>&1 | grep 'ELSPROBLEMS\\|missing\\|invalid' | head -5 && exit 1 || true; fi || true",
     NULL},
    {"supply-chain-pinned-actions",
     "if [ -d .github/workflows ]; then "
     "grep -rn '@main\\|@master\\|@latest' .github/workflows/ 2>/dev/null | grep -v '#' | head -5 && "
     "echo 'warning: GitHub Actions not pinned to SHA' || true; fi || true",
     NULL},
    /* OWASP A10: Empty catch blocks / swallowed errors */
    {"owasp-empty-catch",
     "grep -rn --include='*.ts' --include='*.js' --include='*.java' --include='*.py' --include='*.cpp' "
     "-E 'catch\\s*\\([^)]*\\)\\s*\\{\\s*\\}|except.*:\\s*pass|catch\\s*\\(.*\\)\\s*\\{\\s*\\/\\/' "
     "src/ . 2>/dev/null | grep -v node_modules | grep -v test | head -10",
     NULL},
    /* OWASP A02: Debug mode in production */
    {"owasp-debug-enabled",
     "grep -rn --include='*.py' --include='*.php' --include='*.env' --include='*.yml' --include='*.json' "
     "-iE '(DEBUG\\s*=\\s*[Tt]rue|APP_DEBUG\\s*=\\s*true|\"debug\":\\s*true)' "
     ". 2>/dev/null | grep -v node_modules | grep -v test | grep -v '.env.example' | head -5",
     NULL},
    /* OWASP A02: CORS wildcard */
    {"owasp-cors-wildcard",
     "grep -rn --include='*.ts' --include='*.js' --include='*.py' --include='*.java' --include='*.yml' "
     "-E 'Access-Control-Allow-Origin.*\\*|cors\\(\\)|origin:\\s*[\"'\\']\\*[\"'\\']' "
     "src/ 2>/dev/null | grep -v node_modules | grep -v test | head -5",
     NULL},
    /* OWASP A04: Weak crypto (MD5/SHA1 for security) */
    {"owasp-weak-crypto",
     "grep -rn --include='*.ts' --include='*.js' --include='*.py' --include='*.java' --include='*.cpp' "
     "-E '(md5|MD5|sha1|SHA1)\\(' "
     "src/ . 2>/dev/null | grep -v node_modules | grep -v test | grep -v 'checksum\\|etag\\|cache\\|hash.*file' | head -5",
     NULL},
    /* Vendor lock-in detection */
    {"risk-vendor-lockin",
     "count=0; "
     "aws=$(grep -rl --include='*.ts' --include='*.js' --include='*.py' --include='*.java' "
     "'aws-sdk\\|@aws-sdk\\|boto3\\|software.amazon' src/ . 2>/dev/null | grep -v node_modules | wc -l); "
     "gcp=$(grep -rl --include='*.ts' --include='*.js' --include='*.py' --include='*.java' "
     "'@google-cloud\\|google.cloud\\|com.google.cloud' src/ . 2>/dev/null | grep -v node_modules | wc -l); "
     "azure=$(grep -rl --include='*.ts' --include='*.js' --include='*.py' --include='*.java' "
     "'@azure\\|azure.\\|com.azure' src/ . 2>/dev/null | grep -v node_modules | wc -l); "
     "total=$((aws + gcp + azure)); "
     "if [ $total -gt 10 ]; then "
     "echo \"vendor lock-in risk: $aws AWS, $gcp GCP, $azure Azure files (total: $total cloud-coupled files)\"; "
     "echo \"Consider abstracting cloud dependencies behind interfaces\"; exit 1; fi || true",
     NULL},
    {"risk-platform-lockin",
     "if [ -d .github/workflows ] && ! [ -f Makefile ] && ! [ -f Taskfile.yml ] && ! [ -f justfile ]; then "
     "echo 'Platform lock-in: CI only in GitHub Actions, no portable build (Makefile/Taskfile)'; exit 1; fi || true",
     NULL},
    {"quality-test-to-code-ratio",
     "code=$(find src lib app -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.cpp' -o -name '*.java' -o -name '*.go' -o -name "
     "'*.rs' "
     "2>/dev/null | grep -v test | grep -v spec | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'); "
     "tests=$(find test tests spec src -name '*.test.*' -o -name '*_test.*' -o -name '*spec.*' -o -name 'test_*' "
     "2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'); "
     "code=${code:-0}; tests=${tests:-0}; "
     "if [ \"$code\" -gt 100 ] && [ \"$tests\" -eq 0 ]; then "
     "echo \"No tests for $code lines of code\"; exit 1; "
     "elif [ \"$code\" -gt 100 ] && [ \"$tests\" -gt 0 ]; then "
     "ratio=$((tests * 100 / code)); "
     "if [ $ratio -lt 10 ]; then echo \"Low test-to-code ratio: ${ratio}%\"; exit 1; fi; fi || true",
     NULL},
    {"quality-ai-slop-ratio",
     "slop=$(grep -rl --include='*.cpp' --include='*.ts' --include='*.js' --include='*.py' --include='*.java' "
     "-iE 'this function|this method|this class|self-explanatory|as the name suggests' "
     "src/ lib/ app/ 2>/dev/null | wc -l | tr -d ' '); "
     "total=$(find src lib app -name '*.cpp' -o -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.java' "
     "2>/dev/null | wc -l | tr -d ' '); "
     "if [ \"$total\" -gt 5 ] && [ \"$slop\" -gt 0 ]; then "
     "ratio=$((slop * 100 / total)); "
     "if [ $ratio -gt 50 ]; then echo \"AI slop: ${ratio}% of files contain obvious filler comments\"; exit 1; fi; fi || true",
     NULL},
    {"quality-delta-has-tests",
     "if git rev-parse --git-dir >/dev/null 2>&1; then "
     "code_added=$(git diff --cached --numstat 2>/dev/null | grep -E '\\.(ts|js|py|cpp|java|go|rs)$' | grep -v test | awk "
     "'{s+=$1}END{print s+0}'); "
     "test_added=$(git diff --cached --numstat 2>/dev/null | grep -E 'test|spec' | awk '{s+=$1}END{print s+0}'); "
     "if [ \"$code_added\" -gt 50 ] && [ \"$test_added\" -eq 0 ]; then "
     "echo \"Adding $code_added lines of code with 0 lines of tests\"; exit 1; fi; fi || true",
     NULL},
    {"docs-markdown-complexity-measure",
     "fail=0; "
     "for f in $(find docs -name '*.md' 2>/dev/null); do "
     "  lines=$(wc -l < \"$f\"); "
     "  if [ \"$lines\" -gt 500 ]; then echo \"$f: $lines lines (max 500)\"; fail=1; fi; "
     "  depth=$(grep -c '^#####' \"$f\" 2>/dev/null || true); "
     "  if [ \"$depth\" -gt 0 ]; then echo \"$f: heading depth >4\"; fail=1; fi; "
     "done; exit $fail",
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
