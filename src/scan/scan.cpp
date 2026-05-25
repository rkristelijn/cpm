/**
 * @file scan.cpp
 * @brief Polyrepo scanner — fast file-based quality metrics.
 *
 * Scans directories for git repos and scores them on maturity (0-5).
 * Uses only file I/O (no system() calls) to achieve <1s for 100+ repos.
 * Outputs findings to a central JSONL file for querying.
 *
 * @see docs/adrs/adr-017-polyrepo-scan.md
 */
#include "scan.h"

#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#define popen _popen
#define pclose _pclose
#else
#include <unistd.h>
#endif

#include <algorithm>
#include <filesystem>
#include <map>

/* Path separator — "/" on POSIX, "\\" on Windows */
#ifdef _WIN32
#else
#endif

/* Portable directory check using stat */
static bool is_directory(const std::string& path) {
  struct stat st;
  return stat(path.c_str(), &st) == 0 && S_ISDIR(st.st_mode);
}

/* Forward declarations */
static std::vector<std::string> detect_languages(const std::string& repo_path);

// Check if path contains a file

// Directories to skip during discovery (performance critical)
static bool should_skip(const char* name) {
  return strcmp(name, "node_modules") == 0 || strcmp(name, ".git") == 0 || strcmp(name, "build") == 0 || strcmp(name, "dist") == 0 ||
         strcmp(name, "target") == 0 || strcmp(name, ".cache") == 0 || strcmp(name, "vendor") == 0 || strcmp(name, ".tmp") == 0 ||
         strcmp(name, "out") == 0 || strcmp(name, ".next") == 0 || strcmp(name, "coverage") == 0 || strcmp(name, "__pycache__") == 0;
}

// Recursive directory walk to find .git dirs
static void find_repos(const std::string& path, int depth, int max_depth, std::vector<Repo>& out) {
  if (depth > max_depth) return;

  DIR* d = opendir(path.c_str());
  if (!d) return;

  struct dirent* entry;
  bool is_repo = false;

  while ((entry = readdir(d)) != nullptr) {
    if (entry->d_name[0] == '.') {
      if (strcmp(entry->d_name, ".git") == 0 && is_directory(path + SEP + ".git")) {
        is_repo = true;
        break;
      }
      continue;
    }
  }

  if (is_repo) {
    Repo repo;
    repo.path = path;
    size_t pos = path.rfind('/');
#ifdef _WIN32
    size_t pos2 = path.rfind('\\');
    if (pos2 != std::string::npos && (pos == std::string::npos || pos2 > pos)) pos = pos2;
#endif
    repo.name = (pos != std::string::npos) ? path.substr(pos + 1) : path;
    repo.has_cpm_toml = has_file(path, "cpm.toml");
    repo.languages = detect_languages(path);
    repo.findings_errors = 0;
    repo.findings_warnings = 0;
    out.push_back(repo);
    closedir(d);
    return;
  }

  // Not a repo — recurse into subdirs
  rewinddir(d);
  while ((entry = readdir(d)) != nullptr) {
    if (entry->d_name[0] == '.') continue;
    if (should_skip(entry->d_name)) continue;
    std::string child = path + SEP + entry->d_name;
    if (!is_directory(child)) continue;

    find_repos(child, depth + 1, max_depth, out);
  }
  closedir(d);
}

std::vector<Repo> discover_repos(const std::string& root, int max_depth) {
  std::vector<Repo> repos;
  find_repos(root, 0, max_depth, repos);
  return repos;
}

static std::vector<std::string> detect_languages(const std::string& repo_path) {
  std::vector<std::string> langs;
  if (has_file(repo_path, "tsconfig.json"))
    langs.push_back("typescript");
  else if (has_file(repo_path, "package.json"))
    langs.push_back("javascript");
  if (has_file(repo_path, "CMakeLists.txt")) langs.push_back("cpp");
  if (has_file(repo_path, "Cargo.toml")) langs.push_back("rust");
  if (has_file(repo_path, "pyproject.toml") || has_file(repo_path, "requirements.txt")) langs.push_back("python");
  if (has_file(repo_path, "pom.xml") || has_file(repo_path, "build.gradle")) langs.push_back("java");
  if (has_file(repo_path, "composer.json")) langs.push_back("php");
  if (has_file(repo_path, "go.mod")) langs.push_back("go");
  if (langs.empty()) langs.push_back("other");
  return langs;
}

// Central findings file

/* Check implementations in scan_checks.cpp */

void print_scan_report(const std::vector<Repo>& repos) {
  int total_errors = 0, total_warnings = 0;
  int level0 = 0, level1 = 0, level2 = 0, level3 = 0, level4 = 0, level5 = 0;

  // Maturity levels:
  // 0 Initial:   has errors
  // 1 Managed:   no errors, has README + LICENSE + build system
  // 2 Defined:   + CI pipeline + CONTRIBUTING
  // 3 Measured:  + agent config + cpm.toml + low warnings (<=2)
  // 4 Optimized: + no warnings at all
  // 5 Excellent: level 4 + has tests + hooks + docs/

  for (const auto& r : repos) {
    total_errors += r.findings_errors;
    total_warnings += r.findings_warnings;

    if (r.findings_errors > 0) {
      level0++;
    } else if (r.findings_warnings > 4) {
      level1++;
    } else if (r.findings_warnings > 2) {
      level2++;
    } else if (r.findings_warnings > 0) {
      level3++;
    } else if (!r.has_cpm_toml) {
      level4++;
    } else {
      level5++;
    }
  }

  printf("\n  Scan Report (%zu repos)\n", repos.size());
  printf("  ─────────────────────────────────────────────\n");
  printf("  Errors: %d | Warnings: %d\n\n", total_errors, total_warnings);

  // Maturity distribution
  printf("  Maturity distribution:\n");
  printf("    Level 5 (excellent):  %3d repos  ", level5);
  for (int i = 0; i < level5 && i < 40; i++) printf("█");
  printf("\n");
  printf("    Level 4 (optimized):  %3d repos  ", level4);
  for (int i = 0; i < level4 && i < 40; i++) printf("█");
  printf("\n");
  printf("    Level 3 (measured):   %3d repos  ", level3);
  for (int i = 0; i < level3 && i < 40; i++) printf("█");
  printf("\n");
  printf("    Level 2 (defined):    %3d repos  ", level2);
  for (int i = 0; i < level2 && i < 40; i++) printf("█");
  printf("\n");
  printf("    Level 1 (managed):    %3d repos  ", level1);
  for (int i = 0; i < level1 && i < 40; i++) printf("█");
  printf("\n");
  printf("    Level 0 (initial):    %3d repos  ", level0);
  for (int i = 0; i < level0 && i < 40; i++) printf("█");
  printf("\n");
  printf("\n");

  // Sort by findings (worst first)
  std::vector<const Repo*> sorted;
  for (const auto& r : repos) sorted.push_back(&r);
  std::sort(sorted.begin(), sorted.end(), [](const Repo* a, const Repo* b) {
    return (a->findings_errors * 10 + a->findings_warnings) > (b->findings_errors * 10 + b->findings_warnings);
  });

  // Top 10 worst
  printf("  Needs attention (top 10):\n");
  int shown = 0;
  for (const auto* r : sorted) {
    if (r->findings_errors == 0 && r->findings_warnings == 0) break;
    if (shown++ >= 10) break;
    printf("    %-40s %d err, %d warn\n", r->name.c_str(), r->findings_errors, r->findings_warnings);
  }

  // Top 5 best
  printf("\n  Cleanest repos:\n");
  for (int i = sorted.size() - 1; i >= 0 && i >= (int)sorted.size() - 5; i--) {
    const auto* r = sorted[i];
    if (r->findings_errors == 0 && r->findings_warnings <= 1) {
      printf("    %-40s ✓\n", r->name.c_str());
    }
  }
  printf("\n");

  // Language distribution
  std::map<std::string, int> lang_count;
  for (const auto& r : repos)
    for (const auto& l : r.languages) lang_count[l]++;
  if (repos.size() > 10) {
    printf("  Language distribution:\n");
    std::vector<std::pair<std::string, int>> lsorted(lang_count.begin(), lang_count.end());
    std::sort(lsorted.begin(), lsorted.end(), [](auto& a, auto& b) { return a.second > b.second; });
    for (auto& [lang, count] : lsorted) {
      if (count < 2) continue;
      printf("    %-12s %3d repos  ", lang.c_str(), count);
      for (int i = 0; i < count && i < 40; i++) printf("█");
      printf("\n");
    }
    printf("\n");
  }

  // Repo type distribution
  int sw = 0, docs = 0, lists = 0;
  for (const auto& r : repos) {
    if (r.repo_type == "software")
      sw++;
    else if (r.repo_type == "docs")
      docs++;
    else
      lists++;
  }
  if (repos.size() > 10) {
    printf("  Repo types:\n");
    printf("    Software:  %3d (%d%%)\n", sw, sw * 100 / (int)repos.size());
    printf("    Docs:      %3d (%d%%)\n", docs, docs * 100 / (int)repos.size());
    printf("    Lists:     %3d (%d%%)\n", lists, lists * 100 / (int)repos.size());
    printf("\n");
  }
}

int cmd_scan(int argc, char* argv[]) {
  ScanOptions opts;
  opts.root_path = ".";
  opts.max_depth = 3;

  // Parse args
  for (int i = 0; i < argc; i++) {
    if (argv[i][0] != '-') {
      opts.root_path = argv[i];
    } else if (strcmp(argv[i], "--depth") == 0 && i + 1 < argc) {
      opts.max_depth = atoi(argv[++i]);
    } else if (strcmp(argv[i], "--lang") == 0 && i + 1 < argc) {
      opts.lang_filter = argv[++i];
    }
  }

  printf("\n  Scanning %s (depth %d)...\n\n", opts.root_path.c_str(), opts.max_depth);

  // Open central findings file
  std::string findings_path = std::string(getenv("HOME") ? getenv("HOME") : ".") + "/.local/share/cpm/scan-findings.jsonl";
  std::filesystem::create_directories(findings_path.substr(0, findings_path.rfind('/')));
  g_findings_file = fopen(findings_path.c_str(), "w");  // overwrite per scan

  auto repos = discover_repos(opts.root_path, opts.max_depth);

  // Filter by language if specified
  if (!opts.lang_filter.empty()) {
    repos.erase(std::remove_if(repos.begin(), repos.end(),
                               [&](const Repo& r) {
                                 for (const auto& l : r.languages)
                                   if (l.find(opts.lang_filter) != std::string::npos) return false;
                                 return true;
                               }),
                repos.end());
  }

  printf("  Found %zu repos\n\n", repos.size());

  // Run checks
  for (size_t i = 0; i < repos.size(); i++) {
    int findings = run_repo_checks(repos[i], opts);
    if (findings > 0) {
      printf("  [%zu/%zu] %-40s %d findings\n", i + 1, repos.size(), repos[i].name.c_str(), findings);
    } else {
      printf("  [%zu/%zu] %-40s ✓\n", i + 1, repos.size(), repos[i].name.c_str());
    }
  }

  print_scan_report(repos);

  if (g_findings_file) {
    fclose(g_findings_file);
    printf("  Findings: %s\n", findings_path.c_str());
    printf("  Query:    grep '\"severity\":\"error\"' %s\n\n", findings_path.c_str());
  }

  return 0;
}
