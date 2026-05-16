/* main.cpp — cpm: code project maturity
 *
 * Entry point and CLI dispatch. This file is intentionally thin:
 * all logic lives in commands.cpp (project ops) and checks.cpp (quality gates).
 *
 * Design: single dispatch table maps argv[1] to handler functions.
 * Commands that don't need cpm.toml (init, new, scan) are dispatched first,
 * then we parse config and dispatch the rest.
 */
#include <stdio.h>
#include <string.h>

#include "checks.h"
#include "commands.h"
#include "scan.h"
#include "setup.h"
#include "toml.h"

/* Version is the single source of truth — also in cpm.toml for the project */
#define CPM_VERSION "0.1.0"
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
      "  help             Show this help\n",
      CPM_VERSION);
}

int main(int argc, char* argv[]) {
  /* No args = show help (non-error, exit 0) */
  if (argc < 2) { usage(); return 0; }

  const char* cmd = argv[1];

  /* Help and version flags — handle before anything else */
  if (strcmp(cmd, "help") == 0 || strcmp(cmd, "-h") == 0 || strcmp(cmd, "--help") == 0) {
    usage(); return 0;
  }
  if (strcmp(cmd, "--version") == 0 || strcmp(cmd, "-V") == 0) {
    printf("cpm %s\n", CPM_VERSION); return 0;
  }

  /* --- Commands that work without cpm.toml --- */
  /* These must work in any directory (bootstrapping, scanning) */
  if (strcmp(cmd, "init") == 0) return cmd_init();
  if (strcmp(cmd, "new") == 0)  return cmd_new(argc, argv);
  if (strcmp(cmd, "scan") == 0) return cmd_scan(argc - 2, argv + 2);

  /* --- Commands that require cpm.toml --- */
  /* Parse config first; fail early with helpful message if missing */
  CpmConfig cfg;
  if (cpm_toml_parse(CPM_FILE, &cfg) != 0) {
    fprintf(stderr, "Error: %s not found. Run 'cpm init' to create one.\n", CPM_FILE);
    return 1;
  }

  /* Dispatch to command handlers */
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
  else if (strcmp(cmd, "set") == 0)       return cmd_set(argc > 2 ? argv[2] : NULL, argc > 3 ? argv[3] : NULL);
  else if (strcmp(cmd, "version") == 0) {
    /* "version" alone shows version; "version patch" bumps */
    if (argc > 2) return cmd_bump(&cfg, argv[2]);
    printf("%s\n", cfg.version);
    return 0;
  }
  else if (strcmp(cmd, "tools") == 0)     { cpm_versions(&cfg); return 0; }
  else {
    fprintf(stderr, "Unknown command: %s\n", cmd);
    usage();
    return 1;
  }
}
