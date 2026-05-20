/**
// @see ADR-129
 * @file setup.cpp
 * @brief Tool installation — installs quality tools from cpm.toml.
 *
 * Detects platform (macOS/Linux/Alpine/Windows) and uses the appropriate
 * package manager: brew, apt, apk, or winget/choco.
 *
 * Design: tools are mapped to platform-specific package names because
 * naming varies across package managers (e.g. "llvm" on brew vs "clang-format" on apt).
 * Installation is idempotent — already-installed tools are skipped.
 *
 * The tool list comes from cpm.toml [tools] section. Only tools listed there
 * are installed, giving projects control over their toolchain.
 */
#include "setup.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "runner.h"
#include "ui.h"

/** @brief Maps tool names to platform-specific package names. */
typedef struct {
  const char* tool;
  const char* brew;   /* macOS */
  const char* apt;    /* Debian/Ubuntu */
  const char* apk;    /* Alpine */
  const char* winget; /* Windows */
} PkgMap;

static const PkgMap PKG_MAP[] = {{"llvm", "llvm", "clang-format", "clang-extra-tools", "LLVM.LLVM"},
                                 {"gcc", "gcc", "g++", "g++", NULL},
                                 {"cppcheck", "cppcheck", "cppcheck", "cppcheck", NULL},
                                 {"pmccabe", "pmccabe", "pmccabe", NULL, NULL},
                                 {"cloc", "cloc", "cloc", "cloc", NULL},
                                 {"shellcheck", "shellcheck", "shellcheck", "shellcheck", NULL},
                                 {"shfmt", "shfmt", "shfmt", "shfmt", NULL},
                                 {"yamllint", "yamllint", "yamllint", "py3-yamllint", NULL},
                                 {"gitleaks", "gitleaks", "gitleaks", NULL, NULL},
                                 {"semgrep", "semgrep", NULL, NULL, NULL},
                                 {"doxygen", "doxygen", "doxygen", "doxygen", NULL},
                                 {"rumdl", "rumdl", NULL, NULL, NULL},
                                 {"trivy", "trivy", NULL, "trivy", NULL},
                                 {"ripgrep", "ripgrep", "ripgrep", "ripgrep", NULL},
                                 {NULL, NULL, NULL, NULL, NULL}};

/** @brief Detect platform for package manager selection. */
typedef enum { PLAT_MAC, PLAT_DEBIAN, PLAT_ALPINE, PLAT_WINDOWS, PLAT_UNKNOWN } Platform;

static Platform detect_platform(void) {
#ifdef __APPLE__
  return PLAT_MAC;
#elif defined(_WIN32)
  return PLAT_WINDOWS;
#else
  /* Distinguish Alpine from Debian */
  FILE* f = fopen("/etc/alpine-release", "r");
  if (f) {
    fclose(f);
    return PLAT_ALPINE;
  }
  return PLAT_DEBIAN;
#endif
}

static const char* platform_name(Platform p) {
  switch (p) {
    case PLAT_MAC:
      return "macOS (brew)";
    case PLAT_DEBIAN:
      return "Linux (apt)";
    case PLAT_ALPINE:
      return "Alpine (apk)";
    case PLAT_WINDOWS:
      return "Windows (winget)";
    default:
      return "unknown";
  }
}

static const PkgMap* find_pkg(const char* tool) {
  for (int i = 0; PKG_MAP[i].tool; i++)
    if (strcmp(PKG_MAP[i].tool, tool) == 0) return &PKG_MAP[i];
  return NULL;
}

static const char* pkg_for_platform(const PkgMap* pkg, Platform plat) {
  if (!pkg) return NULL;
  switch (plat) {
    case PLAT_MAC:
      return pkg->brew;
    case PLAT_DEBIAN:
      return pkg->apt;
    case PLAT_ALPINE:
      return pkg->apk;
    case PLAT_WINDOWS:
      return pkg->winget;
    default:
      return NULL;
  }
}

static int install_tool(const char* name, Platform plat) {
  const PkgMap* pkg = find_pkg(name);
  const char* pkg_name = pkg_for_platform(pkg, plat);

  if (!pkg_name) {
    printf("  ⚠ %s: no package for %s\n", name, platform_name(plat));
    return 1;
  }

  char cmd[512];
  switch (plat) {
    case PLAT_MAC:
      snprintf(cmd, sizeof(cmd), "brew install %s 2>&1", pkg_name);
      break;
    case PLAT_DEBIAN:
      snprintf(cmd, sizeof(cmd), "sudo apt-get install -y %s 2>&1", pkg_name);
      break;
    case PLAT_ALPINE:
      snprintf(cmd, sizeof(cmd), "apk add --no-cache %s 2>&1", pkg_name);
      break;
    case PLAT_WINDOWS:
      snprintf(cmd, sizeof(cmd), "winget install -e --id %s 2>&1", pkg_name);
      break;
    default:
      return 1;
  }

  printf("  Installing %s...\n", name);
  return cpm_exec(cmd);
}

/** @brief Map tool name to the binary to check on PATH. */
static const char* tool_binary(const char* name) {
  if (strcmp(name, "llvm") == 0) return "clang-format";
  if (strcmp(name, "gcc") == 0) return "g++";
  if (strcmp(name, "ripgrep") == 0) return "rg";
  return name;
}

int cpm_setup(CpmConfig* cfg) {
  Platform plat = detect_platform();
  printf("==> Installing tools from cpm.toml (%s)...\n\n", platform_name(plat));
  int errors = 0;

  for (int i = 0; i < cfg->tool_count; i++) {
    const char* bin = tool_binary(cfg->tools[i].name);
    if (cpm_has_tool(bin)) {
      printf("  ✓ %s\n", cfg->tools[i].name);
    } else {
      if (install_tool(cfg->tools[i].name, plat) != 0) errors++;
    }
  }

  printf("\n==> Setup %s.\n", errors ? "completed with errors" : "complete");
  return errors;
}

void cpm_versions(CpmConfig* cfg) {
  printf("Tools (%d):\n", cfg->tool_count);
  for (int i = 0; i < cfg->tool_count; i++) {
    const char* bin = tool_binary(cfg->tools[i].name);
    bool found = cpm_has_tool(bin);
    printf("  %-16s %-8s %s\n", cfg->tools[i].name, cfg->tools[i].version, found ? "✓" : "✗ missing");
  }
}
