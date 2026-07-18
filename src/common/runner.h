/**
// @see ADR-129
 * @file runner.h
 * @brief Parallel task runner — executes quality checks using fork/waitpid.
 *
 * Core execution engine. Forks all checks at once for maximum parallelism,
 * buffers output per-task to avoid interleaving, only shows output on failure.
 *
 * Mock support: set CPM_MOCK=1 to skip tool execution (for fast e2e tests).
 */
#ifndef CPM_RUNNER_H
#define CPM_RUNNER_H

#include <stdbool.h>

#include "toml.h"

/** @brief Result of a single check execution. */
typedef struct {
  const char* name;    /**< check identifier */
  const char* command; /**< shell command that was run */
  bool warn_only;      /**< true = failure is a warning, not an error */
  int exit_code;       /**< 0 = pass, non-zero = fail */
  double elapsed_sec;  /**< wall-clock time */
  bool skipped;        /**< true if tool not installed */
} RunResult;

/** @brief Aggregated results from a parallel run. */
typedef struct {
  RunResult* results; /**< array of results (caller must free) */
  int count;          /**< total checks */
  int passed;
  int failed;
  int warned;
  int skipped;
  double total_sec; /**< wall-clock time for entire batch */
} RunSummary;

/**
 * @brief Run commands in parallel using fork().
 * @param names Array of check names (for display).
 * @param commands Array of shell commands (nullptr = skip).
 * @param warn_only Array of booleans (true = warn on failure).
 * @param count Number of checks.
 * @return Summary with results. Caller must free summary.results.
 */
RunSummary cpm_run_parallel(const char** names, const char** commands, const bool* warn_only, int count);

/**
 * @brief Execute a shell command synchronously.
 * @note NOT mocked by CPM_MOCK (used for filesystem ops).
 * @return Exit code of the command.
 */
int cpm_exec(const char* cmd);

/**
 * @brief Check if a command exists on PATH.
 * @note Returns true in CPM_MOCK mode (so checks aren't skipped).
 */
bool cpm_has_tool(const char* name);

/**
 * @brief Get list of files changed since last commit.
 * @param files Output buffer for file paths.
 * @param max Maximum number of files to return.
 * @return Number of changed files found.
 */

#endif
