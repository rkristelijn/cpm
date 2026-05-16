/* scan.h — Polyrepo scanner: discover repos, detect language, run checks.
 * @trace feature:scan, adr:017 */
#pragma once
#include <string>
#include <vector>

struct Repo {
  std::string path;
  std::string name;
  std::vector<std::string> languages;
  bool has_cpm_toml;
  int findings_errors;
  int findings_warnings;
};

struct ScanOptions {
  std::string root_path;
  int max_depth;
  std::string lang_filter;
  std::string check_filter;
  std::string output_format; // terminal, json, csv, junit
};

// Discover git repos under root_path
std::vector<Repo> discover_repos(const std::string &root, int max_depth);

// Detect languages for a repo based on files present
std::vector<std::string> detect_languages(const std::string &repo_path);

// Run checks on a single repo, return findings count
int run_repo_checks(Repo &repo, const ScanOptions &opts);

// Print aggregated report
void print_scan_report(const std::vector<Repo> &repos);

// Entry point for `cpm scan`
int cmd_scan(int argc, char *argv[]);
