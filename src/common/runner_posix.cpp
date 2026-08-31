/**
 * @file runner_posix.cpp
 * @brief POSIX parallel execution engine for cpm (macOS + Linux).
 *
 * Forks all children at once for maximum parallelism, captures each child's
 * output via a dedicated pipe, and collects results in order. This is the
 * fork()/pipe()/waitpid() path — the Windows counterpart is runner_win32.cpp.
 *
 * Selected by the Makefile when OS != Windows_NT. Contains no #ifdef.
 * @see ADR-170
 */
#include "runner.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#include "platform.h"
#include "runner_internal.h"

RunSummary cpm_run_parallel(const char** names, const char** commands, const bool* warn_only, int count) {
  RunSummary s = {};
  s.results = (RunResult*)calloc(count, sizeof(RunResult));
  s.count = count;

  pid_t* pids = (pid_t*)calloc(count, sizeof(pid_t));
  int (*pipes)[2] = (int (*)[2])calloc(count, sizeof(int[2]));
  double start = platform::now_sec();

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

    if (pipe(pipes[i]) != 0) {
      pids[i] = -1;
      s.results[i].exit_code = 1;
      s.results[i].skipped = true;
      s.failed++;
      fprintf(stderr, "cpm: pipe failed for '%s': %s\n", names[i], strerror(errno));
      continue;
    }
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
      _exit(platform::wait_exit(system(wrapped)));
    }
    close(pipes[i][1]);
  }

  /* Phase 2: collect results in order */
  for (int i = 0; i < count; i++) {
    if (pids[i] <= 0) continue;

    double t0 = platform::now_sec();
    int status;
    waitpid(pids[i], &status, 0);
    s.results[i].elapsed_sec = platform::now_sec() - t0;
    s.results[i].exit_code = platform::wait_exit(status);

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

  s.total_sec = platform::now_sec() - start;
  free(pids);
  free(pipes);
  return s;
}
