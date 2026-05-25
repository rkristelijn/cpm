/* main.cpp — cpm: code project maturity
// @see ADR-129
 *
 * Entry point and CLI dispatch. This file is intentionally thin:
 * all logic lives in commands.cpp (project ops) and checks.cpp (quality gates).
 *
 * Design: single dispatch table maps argv[1] to handler functions.
 * Commands that don't need cpm.toml (init, new, scan) are dispatched first,
 * then we parse config and dispatch the rest.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common/compat.h"
#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

/* Windows portability shims */
#ifdef _WIN32
#include <windows.h>
static int setenv(const char* name, const char* value, int overwrite) {
  if (!overwrite && getenv(name)) return 0;
  return _putenv_s(name, value);
}
static ssize_t readlink(const char*, char* buf, size_t bufsize) {
  DWORD len = GetModuleFileNameA(nullptr, buf, (DWORD)bufsize);
  return len > 0 ? (ssize_t)len : -1;
}
#endif

#include "checks.h"
#include "commands/commands.h"
#include "runner.h"
#include "scan/scan.h"
#include "setup.h"
#include "toml.h"

/* Version is defined in commands.h — single source of truth */
#define CPM_FILE "cpm.toml"

/* Print usage to stdout. Follows GNU conventions: program name, synopsis, commands. */
static void usage(void) {
  printf(
      "cpm %s — code project maturity\n\n"
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
      "  version [part]   Show or bump version (major|minor|patch)\n"
      "  tools            Show installed tool versions\n"
      "  hook             Install git hooks\n"
      "  unhook           Remove git hooks\n"
      "  get [key]        Show config (all or specific key)\n"
      "  set <key> <val>  Update config value\n"
      "  scan <path>      Scan repos for quality metrics\n"
      "  score            Show maturity score (0-100) + badge\n"
      "  findings [repo]  Query findings (--severity, --junit)\n"
      "  commit           Interactive conventional commit\n"
      "  issue [title]    Local-first issue tracking (push/pull to GitHub)\n"
      "  todo             Show TODO/FIXME items from scraper\n"
      "  xref             Validate all cross-references\n"
      "  help             Show this help\n",
      CPM_VERSION);
}

int main(int argc, char* argv[]) {
  /* Recursion guard: prevent fork bomb when cpm check → make test → cpm check */
  const char* depth_str = getenv("CPM_DEPTH");
  int depth = depth_str ? atoi(depth_str) : 0;
  if (depth > 2) {
    fprintf(stderr, "cpm: recursion detected (depth %d) — aborting to prevent fork bomb\n", depth);
    return 1;
  }
  char depth_buf[16];
  snprintf(depth_buf, sizeof(depth_buf), "%d", depth + 1);
  setenv("CPM_DEPTH", depth_buf, 1);

  /* No args = show help (non-error, exit 0) */
  if (argc < 2) {
    usage();
    return 0;
  }

  const char* cmd = argv[1];

  /* Always show version + binary location (skip for --version/help to avoid duplication) */
  if (strcmp(cmd, "help") != 0 && strcmp(cmd, "-h") != 0 && strcmp(cmd, "--help") != 0 && strcmp(cmd, "--version") != 0 &&
      strcmp(cmd, "-V") != 0 && depth == 0) {
    char bin_path[512] = "";
#ifdef __APPLE__
    uint32_t size = sizeof(bin_path);
    _NSGetExecutablePath(bin_path, &size);
#else
    readlink("/proc/self/exe", bin_path, sizeof(bin_path) - 1);
#endif
    printf("cpm %s (%s)\n\n", CPM_VERSION, bin_path[0] ? bin_path : argv[0]);
  }

  /* Help and version flags — handle before anything else */
  if (strcmp(cmd, "help") == 0 || strcmp(cmd, "-h") == 0 || strcmp(cmd, "--help") == 0) {
    usage();
    return 0;
  }
  if (strcmp(cmd, "--version") == 0 || strcmp(cmd, "-V") == 0) {
    printf("cpm %s\n", CPM_VERSION);
    return 0;
  }

  /* --- Commands that work without cpm.toml --- */
  /* These must work in any directory (bootstrapping, scanning) */
  if (strcmp(cmd, "init") == 0) return cmd_init();
  if (strcmp(cmd, "new") == 0) return cmd_new(argc, argv);
  if (strcmp(cmd, "scan") == 0) return cmd_scan(argc - 2, argv + 2);
  if (strcmp(cmd, "score") == 0) return cmd_score();
  if (strcmp(cmd, "sbom") == 0) {
    /* Generate SBOM using available tools */
    if (access("package-lock.json", F_OK) == 0 || access("pnpm-lock.yaml", F_OK) == 0)
      return system(
          "npx --yes @cyclonedx/cyclonedx-npm --output-file sbom.json 2>&1 || "
          "echo 'Install: npm install -g @cyclonedx/cyclonedx-npm'");
    if (access("Cargo.lock", F_OK) == 0)
      return system("cargo cyclonedx --format json 2>&1 || echo 'Install: cargo install cargo-cyclonedx'");
    if (access("go.sum", F_OK) == 0)
      return system(
          "cyclonedx-gomod app -json -output sbom.json 2>&1 || echo 'Install: go install "
          "github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest'");
    if (access("pom.xml", F_OK) == 0)
      return system("mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q 2>&1 || echo 'Install: add cyclonedx-maven-plugin to pom.xml'");
    if (access("composer.lock", F_OK) == 0)
      return system("composer make-bom 2>&1 || echo 'Install: composer require --dev cyclonedx/cyclonedx-php-composer'");
    printf("No supported lockfile found (package-lock.json, Cargo.lock, go.sum, pom.xml, composer.lock)\n");
    return 1;
  }
  if (strcmp(cmd, "findings") == 0) return cmd_findings(argc - 2, argv + 2);
  if (strcmp(cmd, "report") == 0) return cmd_report(argc - 2, argv + 2);
  if (strcmp(cmd, "commit") == 0) return cmd_commit();
  if (strcmp(cmd, "issue") == 0) return cmd_issue(argc - 2, argv + 2);
  if (strcmp(cmd, "todo") == 0) return cmd_todo(argc - 2, argv + 2);
  if (strcmp(cmd, "xref") == 0) return cmd_xref(argc - 2, argv + 2);

  /* --- Commands that require config --- */
  /* Parse config; use defaults if cpm.toml is missing */
  CpmConfig cfg;
  if (cpm_toml_parse(CPM_FILE, &cfg) != 0) {
    /* Auto-detect: no cpm.toml, use defaults + detect lang from files */
    cpm_toml_defaults(&cfg);
  }

  /* Apply config timeout if env not already set */
  if (!getenv("CPM_TIMEOUT") && cfg.timeout > 0) {
    char buf[16];
    snprintf(buf, sizeof(buf), "%d", cfg.timeout);
    setenv("CPM_TIMEOUT", buf, 0);
  }

  /* Dispatch to command handlers */
  if (strcmp(cmd, "install") == 0)
    return cmd_install(&cfg);
  else if (strcmp(cmd, "uninstall") == 0)
    return cmd_uninstall(argc, argv);
  else if (strcmp(cmd, "check") == 0)
    return cmd_check_gate(&cfg, argc > 2 ? argv[2] : nullptr);
  else if (strcmp(cmd, "lint") == 0)
    return cmd_check(&cfg, argc > 2 ? argv[2] : nullptr);
  else if (strcmp(cmd, "format") == 0)
    return cmd_format(&cfg);
  else if (strcmp(cmd, "phase") == 0) {
    char cmd_buf[512], bin_dir3[512] = "";
#ifdef __APPLE__
    uint32_t sz4 = sizeof(bin_dir3);
    _NSGetExecutablePath(bin_dir3, &sz4);
#else
    readlink("/proc/self/exe", bin_dir3, sizeof(bin_dir3) - 1);
#endif
    char* ls3 = strrchr(bin_dir3, '/');
    if (ls3) *ls3 = '\0';
    snprintf(cmd_buf, sizeof(cmd_buf), "bash %s/lib/shell/phase.sh %s", bin_dir3, argc > 2 ? argv[2] : "");
    return cpm_exec(cmd_buf);
  } else if (strcmp(cmd, "guard") == 0) {
    char cmd_buf[512], bin_dir2[512] = "";
#ifdef __APPLE__
    uint32_t sz3 = sizeof(bin_dir2);
    _NSGetExecutablePath(bin_dir2, &sz3);
#else
    readlink("/proc/self/exe", bin_dir2, sizeof(bin_dir2) - 1);
#endif
    char* ls2 = strrchr(bin_dir2, '/');
    if (ls2) *ls2 = '\0';
    snprintf(cmd_buf, sizeof(cmd_buf), "bash %s/lib/shell/guard.sh %s", bin_dir2, argc > 2 ? argv[2] : "");
    return cpm_exec(cmd_buf);
  } else if (strcmp(cmd, "flow") == 0) {
    char cmd_buf[512];
    snprintf(cmd_buf, sizeof(cmd_buf), "bash %s/../lib/shell/flow.sh", argv[0]);
    /* Resolve from binary path */
    char bin_dir[512] = "";
#ifdef __APPLE__
    uint32_t sz2 = sizeof(bin_dir);
    _NSGetExecutablePath(bin_dir, &sz2);
#else
    readlink("/proc/self/exe", bin_dir, sizeof(bin_dir) - 1);
#endif
    char* ls = strrchr(bin_dir, '/');
    if (ls) *ls = '\0';
    snprintf(cmd_buf, sizeof(cmd_buf), "bash %s/lib/shell/flow.sh", bin_dir);
    return cpm_exec(cmd_buf);
  } else if (strcmp(cmd, "fix") == 0) {
    const char* sub = argc > 2 ? argv[2] : "";
    const char* flag = argc > 3 ? argv[3] : "";
    char bin_dir[512] = "";
#ifdef __APPLE__
    uint32_t sz = sizeof(bin_dir);
    _NSGetExecutablePath(bin_dir, &sz);
#else
    readlink("/proc/self/exe", bin_dir, sizeof(bin_dir) - 1);
#endif
    /* Strip binary name to get directory */
    char* last_slash = strrchr(bin_dir, '/');
    if (last_slash) *last_slash = '\0';
    char cmd_buf[1024];
    if (strcmp(sub, "sql") == 0)
      snprintf(cmd_buf, sizeof(cmd_buf), "bash %s/lib/shell/fix-sql.sh %s", bin_dir, flag);
    else {
      printf("Usage: cpm fix sql [--apply]\n");
      return 1;
    }
    return cpm_exec(cmd_buf);
  } else if (strcmp(cmd, "build") == 0)
    return cmd_build(&cfg);
  else if (strcmp(cmd, "run") == 0)
    return cmd_run(&cfg);
  else if (strcmp(cmd, "test") == 0)
    return cmd_test(&cfg);
  else if (strcmp(cmd, "coverage") == 0)
    return cmd_coverage(&cfg);
  else if (strcmp(cmd, "clean") == 0)
    return cmd_clean(&cfg);
  else if (strcmp(cmd, "eject") == 0)
    return cmd_eject(&cfg);
  else if (strcmp(cmd, "audit") == 0)
    return cmd_audit(&cfg);
  else if (strcmp(cmd, "bump") == 0)
    return cmd_bump(&cfg, argc > 2 ? argv[2] : nullptr);
  else if (strcmp(cmd, "hook") == 0)
    return cmd_hook(&cfg);
  else if (strcmp(cmd, "unhook") == 0)
    return cmd_unhook();
  else if (strcmp(cmd, "get") == 0)
    return cmd_get(&cfg, argc > 2 ? argv[2] : nullptr);
  else if (strcmp(cmd, "set") == 0)
    return cmd_set(argc > 2 ? argv[2] : nullptr, argc > 3 ? argv[3] : nullptr);
  else if (strcmp(cmd, "version") == 0) {
    /* "version" alone shows version; "version patch" bumps */
    if (argc > 2) return cmd_bump(&cfg, argv[2]);
    printf("%s\n", cfg.version);
    return 0;
  } else if (strcmp(cmd, "tools") == 0) {
    cpm_versions(&cfg);
    return 0;
  } else {
    fprintf(stderr, "Unknown command: %s\n", cmd);
    usage();
    return 1;
  }
}
