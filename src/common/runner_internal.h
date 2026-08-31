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

/** @brief Default per-check timeout in seconds (0 = no timeout, env CPM_TIMEOUT). */
int cpm_check_timeout(void);

#endif
