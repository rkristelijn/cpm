/**
// @see ADR-129
 * @file runner.cpp
 * @brief Parallel task runner using fork/waitpid.
 *
 * Core execution engine for cpm. Runs quality checks in parallel using
 * POSIX fork() for maximum throughput on multi-core systems.
 *
 * Design decisions:
 * - fork() over threads: simpler, no shared state, natural process isolation
 * - Pipe per child: captures stdout/stderr without interleaving
 * - Output only on failure: keeps success output clean
 * - CPM_MOCK env var: skips tool execution for fast e2e testing
 *
 * The mock only affects cpm_run_parallel (slow tool calls) and cpm_has_tool,
 * NOT cpm_exec (which handles fast filesystem ops like mkdir, sed, cp).
 */
#include "runner.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#define popen _popen
#define pclose _pclose
#else
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

/** @brief Default per-check timeout in seconds (0 = no timeout). */
static int cpm_check_timeout(void) {
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
  char cmd[256];
#ifdef _WIN32
  snprintf(cmd, sizeof(cmd), "where %s >nul 2>&1", name);
#else
  snprintf(cmd, sizeof(cmd), "command -v %s >/dev/null 2>&1", name);
#endif
  return system(cmd) == 0;
}

/**
 * @brief Execute a shell command synchronously.
 *
 * Used for filesystem operations (mkdir, sed, cp) in commands.cpp.
 * NOT mocked — these are fast and needed for correct behavior in tests.
 */
int cpm_exec(const char* cmd) {
  if (getenv("CPM_MOCK")) return 0;
  int ret = system(cmd);
#ifdef _WIN32
  return ret;
#else
  if (WIFEXITED(ret)) return WEXITSTATUS(ret);
  return 1;
#endif
}

/** @brief Get list of files changed since last commit (for incremental checks). */

/** @brief High-resolution wall-clock timer. */
static double now_sec(void) {
#ifdef _WIN32
  LARGE_INTEGER freq, count;
  QueryPerformanceFrequency(&freq);
  QueryPerformanceCounter(&count);
  return (double)count.QuadPart / freq.QuadPart;
#else
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  return tv.tv_sec + tv.tv_usec / 1e6;
#endif
}

/**
 * @brief Run multiple commands in parallel using fork().
 *
 * Algorithm:
 * 1. Fork all children at once (maximum parallelism)
 * 2. Each child runs its command via system(), exits with its status
 * 3. Parent waits for all children in order, collects results
 *
 * In CPM_MOCK mode, children exit immediately with status 0.
 * This makes e2e tests run in <1s instead of 30-60s.
 */
RunSummary cpm_run_parallel(const char** names, const char** commands, const bool* warn_only, int count) {
  RunSummary s = {};
  s.results = (RunResult*)calloc(count, sizeof(RunResult));
  s.count = count;

#ifdef _WIN32
  /* Windows: sequential execution via system() — no fork available */
  double start = now_sec();
  for (int i = 0; i < count; i++) {
    s.results[i].name = names[i];
    s.results[i].command = commands[i];
    s.results[i].warn_only = warn_only[i];

    if (!commands[i] || !commands[i][0]) {
      s.results[i].skipped = true;
      s.skipped++;
      continue;
    }

    if (getenv("CPM_MOCK")) {
      s.results[i].exit_code = 0;
      s.passed++;
      continue;
    }

    double t0 = now_sec();
    int rc = system(commands[i]);
    s.results[i].elapsed_sec = now_sec() - t0;
    s.results[i].exit_code = rc;

    if (rc == 0)
      s.passed++;
    else if (s.results[i].warn_only)
      s.warned++;
    else
      s.failed++;
  }
  s.total_sec = now_sec() - start;
#else
  /* POSIX: parallel execution via fork() */
  pid_t* pids = (pid_t*)calloc(count, sizeof(pid_t));
  int (*pipes)[2] = (int (*)[2])calloc(count, sizeof(int[2]));
  double start = now_sec();

  /* Phase 1: fork all children */
  for (int i = 0; i < count; i++) {
    s.results[i].name = names[i];
    s.results[i].command = commands[i];
    s.results[i].warn_only = warn_only[i];

    /* nullptr command = tool not installed, skip */
    if (!commands[i] || !commands[i][0]) {
      s.results[i].skipped = true;
      s.skipped++;
      pids[i] = -1;
      continue;
    }

    pipe(pipes[i]);
    pids[i] = fork();

    if (pids[i] < 0) {
      close(pipes[i][0]);
      close(pipes[i][1]);
      s.results[i].skipped = true;
      s.skipped++;
      fprintf(stderr, "cpm: fork failed for '%s' — system resource limit reached\n", names[i]);
      for (int j = i + 1; j < count; j++) {
        s.results[j].name = names[j];
        s.results[j].skipped = true;
        s.skipped++;
      }
      break;
    }

    if (pids[i] == 0) {
      /* Child: redirect output to pipe, run command */
      close(pipes[i][0]);
      dup2(pipes[i][1], STDOUT_FILENO);
      dup2(pipes[i][1], STDERR_FILENO);
      close(pipes[i][1]);
      if (getenv("CPM_MOCK")) _exit(0);
      int timeout = cpm_check_timeout();
      char wrapped[8192];
      if (timeout > 0) {
        char escaped[4096];
        int j = 0;
        for (int k = 0; commands[i][k] && j < 4090; k++) {
          if (commands[i][k] == '\'') {
            escaped[j++] = '\'';
            escaped[j++] = '\\';
            escaped[j++] = '\'';
            escaped[j++] = '\'';
          } else
            escaped[j++] = commands[i][k];
        }
        escaped[j] = 0;
        snprintf(wrapped, sizeof(wrapped), "timeout %d sh -c '%s'", timeout, escaped);
      } else {
        snprintf(wrapped, sizeof(wrapped), "%s", commands[i]);
      }
      int rc = system(wrapped);
      _exit(WIFEXITED(rc) ? WEXITSTATUS(rc) : 1);
    }
    close(pipes[i][1]);
  }

  /* Phase 2: collect results in order */
  for (int i = 0; i < count; i++) {
    if (pids[i] <= 0) continue;

    double t0 = now_sec();
    int status;
    waitpid(pids[i], &status, 0);
    s.results[i].elapsed_sec = now_sec() - t0;
    s.results[i].exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 1;

    char buf[4096];
    ssize_t n;
    while ((n = read(pipes[i][0], buf, sizeof(buf) - 1)) > 0) {
      buf[n] = '\0';
      if (s.results[i].exit_code != 0) fputs(buf, stderr);
    }
    close(pipes[i][0]);

    if (s.results[i].exit_code == 0)
      s.passed++;
    else if (s.results[i].warn_only)
      s.warned++;
    else
      s.failed++;
  }

  s.total_sec = now_sec() - start;
  free(pids);
  free(pipes);
#endif
  return s;
}
