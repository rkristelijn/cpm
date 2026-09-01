/**
 * @file runner_internal.h
 * @brief Internal helpers shared between runner.cpp and the per-platform
 *        runner implementations (runner_posix.cpp / runner_win32.cpp).
 *
 * Not part of the public runner.h API.
 * @see ADR-170
 */
#ifndef CPM_RUNNER_INTERNAL_H
#define CPM_RUNNER_INTERNAL_H

#include <stdbool.h>

/** @brief Default per-check timeout in seconds (0 = no timeout, env CPM_TIMEOUT). */
int cpm_check_timeout(void);

/**
 * @brief Build the shell command actually executed by a child worker.
 *
 * When @p timeout_sec > 0 the command is single-quote-escaped and wrapped in
 * `timeout <n> sh -c '<cmd>'`; otherwise it is copied verbatim. Extracted from
 * the fork() child path so it can be unit-tested in the parent process (gcov
 * cannot observe a child that ends with _exit()).
 *
 * @param out         Destination buffer for the wrapped command.
 * @param out_size    Size of @p out in bytes.
 * @param command     The raw shell command to run.
 * @param timeout_sec Per-check timeout; <= 0 means no timeout wrapper.
 * @return true on success, false if the command did not fit in the buffer.
 */
bool cpm_wrap_command(char* out, unsigned long out_size, const char* command, int timeout_sec);

#endif
