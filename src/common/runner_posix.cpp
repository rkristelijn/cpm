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

#include <string>

#include "constants.h"
#include "platform.h"
#include "runner_internal.h"

/* Build the command a worker child runs. Extracted so the escaping/timeout
 * logic is unit-testable in the parent (gcov can't see past a child _exit).
 * @see ADR-170 */
bool cpm_wrap_command(char* out, unsigned long out_size, const char* command, int timeout_sec) {
  if (!out || out_size == 0 || !command) return false;

  if (timeout_sec > 0) {
    char escaped[CPM_CMD_BUF];
    unsigned long j = 0;
    for (unsigned long k = 0; command[k] && j + 4 < sizeof(escaped); k++) {
      if (command[k] == '\'') {
        escaped[j++] = '\'';
        escaped[j++] = '\\';
        escaped[j++] = '\'';
        escaped[j++] = '\'';
      } else {
        escaped[j++] = command[k];
      }
    }
    escaped[j] = 0;
    int n = snprintf(out, out_size, "timeout %d sh -c '%s'", timeout_sec, escaped);
    return n > 0 && (unsigned long)n < out_size;
  }

  int n = snprintf(out, out_size, "%s", command);
  return n >= 0 && (unsigned long)n < out_size;
}

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

    /* GCOVR_EXCL_START — OS resource-exhaustion paths; only reachable via
     * fault injection (pipe/fork failure), not exercisable in unit tests. */
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
    /* GCOVR_EXCL_STOP */

    if (pids[i] == 0) {
      /* Child: redirect output to pipe, run command.
       * GCOVR_EXCL_START — the child ends with _exit(), which bypasses the
       * gcov counter flush, so this branch is fundamentally unobservable by
       * coverage. The wrapping logic it depends on is unit-tested directly
       * via cpm_wrap_command(). @see ADR-170 */
      close(pipes[i][0]);
      dup2(pipes[i][1], STDOUT_FILENO);
      dup2(pipes[i][1], STDERR_FILENO);
      close(pipes[i][1]);
      if (getenv("CPM_MOCK")) _exit(0);
      char wrapped[CPM_WRAPPED_CMD_BUF];
      if (!cpm_wrap_command(wrapped, sizeof(wrapped), commands[i], cpm_check_timeout())) {
        fprintf(stderr, "cpm: command too long for '%s'\n", names[i]);
        _exit(1);
      }
      _exit(platform::wait_exit(system(wrapped)));
      /* GCOVR_EXCL_STOP */
    }
    close(pipes[i][1]);
  }

  /* Phase 2: collect results in order */
  for (int i = 0; i < count; i++) {
    if (pids[i] <= 0) continue;

    double t0 = platform::now_sec();

    /* Drain the pipe to EOF BEFORE waitpid. If we waited first, a child that
     * writes more than the pipe capacity (~64 KiB) would block in write()
     * while we block in waitpid() — a deadlock. Verbose checks (clang-tidy,
     * cppcheck, semgrep) easily exceed that. @see ADR-170 */
    char buf[CPM_READ_BUF];
    ssize_t n;
    std::string out;
    bool truncated = false;
    while ((n = read(pipes[i][0], buf, sizeof(buf) - 1)) > 0) {
      buf[n] = '\0';
      /* Keep draining the pipe to EOF (never stop reading — that would
       * reintroduce the write()/waitpid() deadlock), but stop appending once
       * we hit the retention cap so a verbose child can't exhaust memory. */
      if (out.size() < CPM_MAX_CHILD_OUTPUT) {
        size_t room = CPM_MAX_CHILD_OUTPUT - out.size();
        out.append(buf, (size_t)n < room ? (size_t)n : room);
        if ((size_t)n > room) truncated = true;
      } else {
        truncated = true;
      }
    }
    close(pipes[i][0]);
    if (truncated) out += "\n[cpm: output truncated at 4 MiB]\n";

    int status;
    waitpid(pids[i], &status, 0);
    s.results[i].elapsed_sec = platform::now_sec() - t0;
    s.results[i].exit_code = platform::wait_exit(status);
    if (s.results[i].exit_code != 0) fputs(out.c_str(), stderr);

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
