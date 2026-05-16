/**
 * @file checks.h
 * @brief Quality gate — tiered check execution (fast/default/full).
 *
 * Defines what gets checked and orchestrates parallel execution.
 * The tiered gate maps to git workflow stages:
 * - fast:    pre-commit (format + build, <5s)
 * - default: pre-push (+ lint + test, <60s)
 * - full:    CI (+ coverage + sast)
 */
#ifndef CPM_CHECKS_H
#define CPM_CHECKS_H

#include "toml.h"

/** @brief Run all lint checks (same as `cpm lint`). */
int cmd_check(CpmConfig *cfg, const char *filter);

/** @brief Run format checks and fix files in-place. */
int cmd_format(CpmConfig *cfg);

/** @brief Run tiered quality gate (--fast, default, --full). */
int cmd_check_gate(CpmConfig *cfg, const char *tier);

#endif
