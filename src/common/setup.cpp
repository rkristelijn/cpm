/**
// @see ADR-129
 * @file setup.cpp
 * @brief Tool installation — installs quality tools from cpm.toml.
 *
 * Detects platform (macOS/Linux/Alpine/Windows) and uses the appropriate
 * package manager: brew, apt, apk, or winget/choco.
 */
#include "setup.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "platform.h"
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
                                 {"gcc", "gcc", "g++", "g++", nullptr},
                                 {"cppcheck", "cppcheck", "cppcheck", "cppcheck", nullptr},
                                 {"pmccabe", "pmccabe", "pmccabe", nullptr, nullptr},
                                 {"cloc", "cloc", "cloc", "cloc", nullptr},
                                 {"shellcheck", "shellcheck", "shellcheck", "shellcheck", nullptr},
                                 {"shfmt", "shfmt", "shfmt", "shfmt", nullptr},
                                 {"yamllint", "yamllint", "yamllint", "py3-yamllint", nullptr},
                                 {"gitleaks", "gitleaks", "gitleaks", nullptr, nullptr},
                                 {"semgrep", "semgrep", nullptr, nullptr, nullptr},
                                 {"doxygen", "doxygen", "doxygen", "doxygen", nullptr},
                                 {"rumdl", "rumdl", nullptr, nullptr, nullptr},
                                 {"trivy", "trivy", nullptr, "trivy", nullptr},
                                 {"ripgrep", "ripgrep", "ripgrep", "ripgrep", nullptr},
                                 {"vale", "vale", nullptr, nullptr, nullptr},
                                 {"alex", "alexjs", nullptr, nullptr, nullptr},
                                 {"cspell", "cspell", nullptr, nullptr, nullptr},
                                 {"lychee", "lychee", nullptr, nullptr, nullptr},
                                 {"mull", "mull", nullptr, nullptr, nullptr},
                                 {nullptr, nullptr, nullptr, nullptr, nullptr}};

/** @brief Detect platform for package manager selection. */
typedef enum { PLAT_MAC, PLAT_DEBIAN, PLAT_ALPINE, PLAT_WINDOWS, PLAT_UNKNOWN } Platform;

static Platform detect_platform(void) {
  switch (platform::os_kind()) {
    case platform::OsKind::MacOS:
      return PLAT_MAC;
    case platform::OsKind::Windows:
      return PLAT_WINDOWS;
    case platform::OsKind::Alpine:
      return PLAT_ALPINE;
    case platform::OsKind::Linux:
      return PLAT_DEBIAN;
    default:
      return PLAT_UNKNOWN;
  }
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
  return nullptr;
}

static const char* pkg_for_platform(const PkgMap* pkg, Platform plat) {
  if (!pkg) return nullptr;
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
      return nullptr;
  }
}

static int install_tool(const char* name, Platform plat) {
  const PkgMap* pkg = find_pkg(name);
  const char* pkg_name = pkg_for_platform(pkg, plat);

  /* Fallback: try npx for JS tools (no global install needed) */
  if (!pkg_name && pkg) {
    if (strcmp(name, "alex") == 0 || strcmp(name, "cspell") == 0) {
      printf("  skip %s: install via brew (brew install %s) or use npx\n", name, name);
      return 1;
    }
    printf("  skip %s: no package for %s\n", name, platform_name(plat));
    return 1;
  }

  if (!pkg_name) {
    printf("  skip %s: no package for %s\n", name, platform_name(plat));
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

/** @brief Special check for versioned tools (mull-runner-NN). */
bool has_versioned_tool(const char* name) {
  if (strcmp(name, "mull") == 0) {
    return system(
               "ls $(brew --prefix 2>/dev/null)/bin/mull-runner-* /usr/bin/mull-runner-* "
               "/usr/local/bin/mull-runner-* 2>/dev/null | head -1 | grep -q .") == 0;
  }
  return cpm_has_tool(tool_binary(name));
}

int cpm_setup(CpmConfig* cfg) {
  Platform plat = detect_platform();
  printf("==> Installing tools from cpm.toml (%s)...\n\n", platform_name(plat));
  int errors = 0;

  for (int i = 0; i < cfg->tool_count; i++) {
    if (has_versioned_tool(cfg->tools[i].name)) {
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
    bool found = has_versioned_tool(cfg->tools[i].name);
    printf("  %-16s %-8s %s\n", cfg->tools[i].name, cfg->tools[i].version, found ? "✓" : "✗ missing");
  }
}
