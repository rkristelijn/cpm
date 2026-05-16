/**
 * @file scan.h
 * @brief Polyrepo scanner — fast file-based quality metrics for 100+ repos.
 *
 * Scans directories for repos and scores them on maturity (0-5) using
 * only file I/O (no system() calls). Target: 100+ repos in <1 second.
 *
 * @see docs/adrs/adr-017-polyrepo-scan.md
 */
#ifndef CPM_SCAN_H
#define CPM_SCAN_H

#include <string>
#include <vector>

/** @brief Represents a discovered repository with quality metrics. */
struct Repo {
  std::string name;
  std::string path;
  std::vector<std::string> languages;
  bool has_cpm_toml = false;
  int findings_errors = 0;
  int findings_warnings = 0;
};

/** @brief Options for scan execution. */
struct ScanOptions {
  std::string root_path = ".";
  std::string lang_filter;
  int max_depth = 2;
};

/**
 * @brief Entry point for `cpm scan <path> [--depth N]`.
 * @param argc Argument count (after "scan" is stripped).
 * @param argv Arguments: path, optional --depth N.
 * @return 0 on success.
 */
int cmd_scan(int argc, char** argv);

#endif
