/* setup.c — Install tools listed in cpm.toml via brew or apt. */
#include "setup.h"
#include "runner.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Map tool names to brew/apt package names where they differ */
typedef struct { const char *tool; const char *brew; const char *apt; } PkgMap;

static const PkgMap PKG_MAP[] = {
    {"llvm",       "llvm",       NULL},  /* special install */
    {"gcc",        "gcc",        "g++"},
    {"cppcheck",   "cppcheck",   "cppcheck"},
    {"pmccabe",    "pmccabe",    "pmccabe"},
    {"cloc",       "cloc",       "cloc"},
    {"shellcheck", "shellcheck", "shellcheck"},
    {"shfmt",      "shfmt",      "shfmt"},
    {"yamllint",   "yamllint",   "yamllint"},
    {"gitleaks",   "gitleaks",   "gitleaks"},
    {"semgrep",    "semgrep",    NULL},  /* brew only or pipx */
    {"doxygen",    "doxygen",    "doxygen"},
    {"rumdl",      "rumdl",      NULL},  /* direct download */
    {NULL, NULL, NULL}
};

static bool is_mac(void) {
#ifdef __APPLE__
    return true;
#else
    return false;
#endif
}

static const PkgMap *find_pkg(const char *tool) {
    for (int i = 0; PKG_MAP[i].tool; i++)
        if (strcmp(PKG_MAP[i].tool, tool) == 0)
            return &PKG_MAP[i];
    return NULL;
}

static int install_tool(const char *name) {
    const PkgMap *pkg = find_pkg(name);
    const char *pkg_name = pkg ? (is_mac() ? pkg->brew : pkg->apt) : name;

    if (!pkg_name) {
        fprintf(stderr, "  ⚠ %s: no package available for this platform\n", name);
        return 1;
    }

    char cmd[512];
    if (is_mac())
        snprintf(cmd, sizeof(cmd), "brew install %s 2>&1", pkg_name);
    else
        snprintf(cmd, sizeof(cmd), "sudo apt-get install -y %s 2>&1", pkg_name);

    printf("  Installing %s...\n", name);
    return cpm_exec(cmd);
}

/* Map tool name to the actual binary to check on PATH */
static const char *tool_binary(const char *name) {
    if (strcmp(name, "llvm") == 0) return "clang-format";
    if (strcmp(name, "gcc") == 0) return "g++";
    return name;
}

int cpm_setup(CpmConfig *cfg) {
    printf("==> Installing tools from cpm.toml...\n\n");
    int errors = 0;

    for (int i = 0; i < cfg->tool_count; i++) {
        const char *bin = tool_binary(cfg->tools[i].name);
        if (cpm_has_tool(bin)) {
            printf("  ✓ %s\n", cfg->tools[i].name);
        } else {
            if (install_tool(cfg->tools[i].name) != 0)
                errors++;
        }
    }

    printf("\n==> Setup %s.\n", errors ? "completed with errors" : "complete");
    return errors;
}

void cpm_versions(CpmConfig *cfg) {
    printf("Tools (%d):\n", cfg->tool_count);
    for (int i = 0; i < cfg->tool_count; i++) {
        const char *bin = tool_binary(cfg->tools[i].name);
        bool found = cpm_has_tool(bin);
        printf("  %-16s %-8s %s\n",
               cfg->tools[i].name,
               cfg->tools[i].version,
               found ? "✓" : "✗ missing");
    }
}
