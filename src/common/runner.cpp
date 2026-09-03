/**
// @see ADR-129
 * @file runner.cpp
 * @brief Platform-agnostic runner helpers.
 *
 * The parallel execution engine (cpm_run_parallel) is platform-divergent
 * and lives in runner_posix.cpp (fork/pipe/waitpid) and runner_win32.cpp
 * (sequential system()), selected by the Makefile. @see ADR-170
 *
 * This file holds only the platform-agnostic helpers, expressed through
 * the platform:: abstraction so it contains no #ifdef.
 *
 * The mock only affects cpm_run_parallel (slow tool calls) and cpm_has_tool,
 * NOT cpm_exec (which handles fast filesystem ops like mkdir, sed, cp).
 */
#include "runner.h"

#include <stdlib.h>

#include "compat.h"
#include "platform.h"
#include "runner_internal.h"

/** @brief Default per-check timeout in seconds (0 = no timeout). */
int cpm_check_timeout(void) {
  const char* env = getenv("CPM_TIMEOUT");
  return env ? atoi(env) : 30;
}

/**
 * @brief Check if a tool binary exists on PATH.
 *
 * In CPM_MOCK mode, all tools are "available" so checks don't get skipped.
 * This allows e2e tests to exercise the full check pipeline without
 * requiring every tool to be installed.
 */
bool cpm_has_tool(const char* name) {
  if (getenv("CPM_MOCK")) return true;
  return system(platform::cmd_which(name).c_str()) == 0;
}

/**
 * @brief Execute a shell command synchronously.
 *
 * Used for filesystem operations (mkdir, sed, cp) in commands.cpp.
 * NOT mocked — these are fast and needed for correct behavior in tests.
 */
int cpm_exec(const char* cmd) {
  if (getenv("CPM_MOCK")) return 0;
  return platform::wait_exit(system(cmd));
}
