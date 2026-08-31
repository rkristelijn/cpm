/**
 * @file runner_win32.cpp
 * @brief Windows sequential execution engine for cpm.
 *
 * Windows has no fork(), so checks run sequentially via system(). Output is
 * inherited by the console (not captured per-check). This is the Windows
 * counterpart to runner_posix.cpp's fork()/pipe() implementation.
 *
 * Selected by the Makefile when OS == Windows_NT. Contains no #ifdef.
 * @see ADR-170
 */
#include "runner.h"

#include <stdlib.h>

#include "platform.h"
#include "runner_internal.h"

RunSummary cpm_run_parallel(const char** names, const char** commands, const bool* warn_only, int count) {
  RunSummary s = {};
  s.results = (RunResult*)calloc(count, sizeof(RunResult));
  s.count = count;

  double start = platform::now_sec();
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

    double t0 = platform::now_sec();
    int rc = platform::wait_exit(system(commands[i]));
    s.results[i].elapsed_sec = platform::now_sec() - t0;
    s.results[i].exit_code = rc;

    if (rc == 0)
      s.passed++;
    else if (s.results[i].warn_only)
      s.warned++;
    else
      s.failed++;
  }
  s.total_sec = platform::now_sec() - start;
  return s;
}
