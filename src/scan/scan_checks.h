/**
 * @file scan_checks.h
 * @brief Internal header for scan check subfunctions.
 *
 * Each function runs a category of checks on a repo and returns
 * the number of findings added. Called by run_repo_checks().
 */
#ifndef CPM_SCAN_CHECKS_H
#define CPM_SCAN_CHECKS_H

#include "scan.h"

/** @brief Classify repo type (software/docs/list) and detect monorepo. */
int scan_classify(Repo& repo);

/** @brief Language-specific checks (TS/JS, Java, Python, PHP, Go, Rust, Terraform, C++). */
int scan_lang(Repo& repo);

/** @brief CI/CD pipeline checks (GitLab CI). */
int scan_ci(Repo& repo);

/** @brief Universal checks: tests, staleness, git health, standards, secrets. */
int scan_universal(Repo& repo);

#endif
