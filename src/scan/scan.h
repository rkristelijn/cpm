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

#include <sys/stat.h>

#include <string>
#include <vector>

#ifdef _WIN32
static constexpr char PATH_SEP = '\\';
#else
static constexpr char PATH_SEP = '/';
#endif
static const std::string SEP(1, PATH_SEP);

/** @brief Check if a file exists in a directory. */
inline bool has_file(const std::string& dir, const char* name) {
  std::string full = dir + SEP + name;
  struct stat st;
  return stat(full.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

/** @brief Represents a discovered repository with quality metrics. */
struct Repo {
  std::string name;
  std::string path;
  std::vector<std::string> languages;
  bool has_cpm_toml = false;
  int findings_errors = 0;
  int findings_warnings = 0;
  std::string repo_type = "software";  // software, docs, list
  bool is_monorepo = false;
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

/** @brief Run all file-based checks on a repo. */
int run_repo_checks(Repo& repo, const ScanOptions& opts);

/** @brief Global findings file handle (shared between scan.cpp and scan_checks.cpp). */
extern FILE* g_findings_file;

/** @brief Write a finding to the JSONL file. */
void finding_write(const char* repo, const char* check, const char* severity, const char* file, const char* rule, const char* message);

/** @brief Escape a string for safe use in shell single-quotes. */
inline std::string shell_escape(const std::string& s) {
  std::string out = "'";
  for (char c : s) {
    if (c == '\'')
      out += "'\\''";
    else
      out += c;
  }
  out += "'";
  return out;
}

#endif
