/* runner.h — Parallel task runner for cpm */
#ifndef CPM_RUNNER_H
#define CPM_RUNNER_H

#include "toml.h"
#include <stdbool.h>

typedef struct {
    const char *name;
    const char *command;
    bool        warn_only;
    int         exit_code;
    double      elapsed_sec;
    bool        skipped;
} RunResult;

typedef struct {
    RunResult *results;
    int        count;
    int        passed;
    int        failed;
    int        warned;
    int        skipped;
    double     total_sec;
} RunSummary;

/* Run commands in parallel, returns summary. Caller must free summary.results */
RunSummary cpm_run_parallel(const char **names, const char **commands,
                            const bool *warn_only, int count);

/* Run a single command, capture exit code */
int cpm_exec(const char *cmd);

/* Check if a command exists on PATH */
bool cpm_has_tool(const char *name);

/* Get changed files (git diff) into a buffer. Returns count. */
int cpm_changed_files(char files[][256], int max);

#endif
