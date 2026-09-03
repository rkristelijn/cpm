/**
// @see ADR-129
 * @file commands.h
 * @brief CLI command implementations — one function per command.
 *
 * Each cmd_* function implements a single CLI command.
 * Commands return 0 on success, non-zero on failure.
 */
#ifndef CPM_COMMANDS_H
#define CPM_COMMANDS_H

#ifndef CPM_VERSION
#define CPM_VERSION "0.10.0"
#endif

#include "toml.h"

/** @brief Create cpm.toml in current directory with sensible defaults. */
int cmd_init(void);

/** @brief Scaffold a new project, test file, or module. */
int cmd_new(int argc, char* argv[]);

/** @brief Install tools from cpm.toml [tools] section. */
int cmd_install(CpmConfig* cfg);

/** @brief Remove cpm from PATH (--all: remove tools too). */
int cmd_uninstall(int argc, char* argv[]);

/** @brief Build the project (auto-detects Make/CMake/raw compiler). */
int cmd_build(CpmConfig* cfg);

/** @brief Build and run the project binary. */
int cmd_run(CpmConfig* cfg);

/** @brief Run tests (auto-detects Makefile target/CTest/raw). */
int cmd_test(CpmConfig* cfg);

/** @brief Build with gcov instrumentation and report coverage. */
int cmd_coverage(CpmConfig* cfg, int argc, char* argv[]);

/** @brief Remove build artifacts. */
int cmd_clean(CpmConfig* cfg);

/** @brief Generate standalone Makefile, CMakeLists.txt, and tool configs. */
int cmd_eject(CpmConfig* cfg);

/** @brief Install git hooks (per-repo or --global). */
int cmd_hook(CpmConfig* cfg, int argc, char* argv[]);

/** @brief Remove git hooks. */
int cmd_unhook(void);

/** @brief Bump version in cpm.toml (major|minor|patch). */
int cmd_bump(CpmConfig* cfg, const char* part);

/** @brief Show installed tool versions vs pinned versions. */
int cmd_audit(CpmConfig* cfg);

/** @brief Show config values (all or specific key). */
int cmd_get(CpmConfig* cfg, const char* key);

/** @brief Update a config value in cpm.toml. */
int cmd_set(const char* key, const char* val);

/** @brief Query findings database (filter by repo, severity, check). */
int cmd_findings(int argc, char* argv[]);
int cmd_score(void);

/** @brief Generate aggregate report from scan findings (markdown). */
int cmd_report(int argc, char* argv[]);

/** @brief Interactive conventional commit helper. */
int cmd_commit(void);

/** @brief Local-first issue tracking with optional remote sync. */
int cmd_issue(int argc, char* argv[]);

/** @brief Show TODO/FIXME items from scraper output. */
int cmd_todo(int argc, char* argv[]);

/** @brief Validate all cross-references. */
int cmd_xref(int argc, char* argv[]);

/** @brief Canonical sorting toolkit (cpm-toml, ts-imports, lines). */
int cmd_sort(int argc, char* argv[]);

/** @brief Documentation tooling (index generation). @see ADR-171 */
int cmd_docs(int argc, char* argv[]);

#endif
