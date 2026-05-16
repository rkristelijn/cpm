/* scan.cpp — Polyrepo scanner implementation.
 * @trace feature:scan, adr:017 */
#include "scan.h"
#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <algorithm>

// Check if path contains a file
static bool has_file(const std::string &dir, const char *name) {
  std::string full = dir + "/" + name;
  struct stat st;
  return stat(full.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

// Directories to skip during discovery (performance critical)
static bool should_skip(const char *name) {
  return strcmp(name, "node_modules") == 0 || strcmp(name, ".git") == 0 ||
         strcmp(name, "build") == 0 || strcmp(name, "dist") == 0 ||
         strcmp(name, "target") == 0 || strcmp(name, ".cache") == 0 ||
         strcmp(name, "vendor") == 0 || strcmp(name, ".tmp") == 0 ||
         strcmp(name, "out") == 0 || strcmp(name, ".next") == 0 ||
         strcmp(name, "coverage") == 0 || strcmp(name, "__pycache__") == 0;
}

// Recursive directory walk to find .git dirs
static void find_repos(const std::string &path, int depth, int max_depth,
                       std::vector<Repo> &out) {
  if (depth > max_depth) return;

  DIR *d = opendir(path.c_str());
  if (!d) return;

  struct dirent *entry;
  bool is_repo = false;

  while ((entry = readdir(d)) != nullptr) {
    if (entry->d_name[0] == '.') {
      if (strcmp(entry->d_name, ".git") == 0 && entry->d_type == DT_DIR) {
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
    if (entry->d_type != DT_DIR) continue;
    if (should_skip(entry->d_name)) continue;

    std::string child = path + "/" + entry->d_name;
    find_repos(child, depth + 1, max_depth, out);
  }
  closedir(d);
}

std::vector<Repo> discover_repos(const std::string &root, int max_depth) {
  std::vector<Repo> repos;
  find_repos(root, 0, max_depth, repos);
  return repos;
}

std::vector<std::string> detect_languages(const std::string &repo_path) {
  std::vector<std::string> langs;
  if (has_file(repo_path, "tsconfig.json")) langs.push_back("typescript");
  else if (has_file(repo_path, "package.json")) langs.push_back("javascript");
  if (has_file(repo_path, "CMakeLists.txt")) langs.push_back("cpp");
  if (has_file(repo_path, "Cargo.toml")) langs.push_back("rust");
  if (has_file(repo_path, "pyproject.toml") || has_file(repo_path, "requirements.txt"))
    langs.push_back("python");
  if (has_file(repo_path, "pom.xml") || has_file(repo_path, "build.gradle"))
    langs.push_back("java");
  if (has_file(repo_path, "composer.json")) langs.push_back("php");
  if (has_file(repo_path, "go.mod")) langs.push_back("go");
  if (langs.empty()) langs.push_back("other");
  return langs;
}

int run_repo_checks(Repo &repo, const ScanOptions &opts) {
  // Fast checks only — file existence and grep, no external tools.
  // External tools (gitleaks, semgrep) run via `cpm check` per-repo, not during scan.
  int total = 0;

  // Universal: LICENSE exists
  if (!has_file(repo.path, "LICENSE") && !has_file(repo.path, "LICENSE.md")) {
    repo.findings_warnings++;
    total++;
  }

  // Universal: README exists
  if (!has_file(repo.path, "README.md")) {
    repo.findings_warnings++;
    total++;
  }

  // TypeScript/JS checks
  for (const auto &lang : repo.languages) {
    if (lang == "typescript" || lang == "javascript") {
      std::string pkg = repo.path + "/package.json";
      FILE *f = fopen(pkg.c_str(), "r");
      if (f) {
        char buf[65536];
        size_t n = fread(buf, 1, sizeof(buf) - 1, f);
        buf[n] = 0;
        fclose(f);

        // No test script
        if (!strstr(buf, "\"test\"")) { repo.findings_warnings++; total++; }
        // Unpinned deps
        if (strstr(buf, "\"^") || strstr(buf, "\"~")) { repo.findings_warnings++; total++; }
        // Missing description
        if (!strstr(buf, "\"description\"")) { repo.findings_warnings++; total++; }
        // Missing repository
        if (!strstr(buf, "\"repository\"")) { repo.findings_warnings++; total++; }
      }

      // No lockfile
      if (!has_file(repo.path, "package-lock.json") &&
          !has_file(repo.path, "pnpm-lock.yaml") &&
          !has_file(repo.path, "yarn.lock")) {
        repo.findings_errors++;
        total++;
      }
    }

    if (lang == "cpp") {
      // No .clang-format
      if (!has_file(repo.path, ".clang-format") &&
          !has_file(repo.path, ".config/.clang-format")) {
        repo.findings_warnings++;
        total++;
      }
    }
  }

  return total;
}

void print_scan_report(const std::vector<Repo> &repos) {
  int total_errors = 0, total_warnings = 0, clean = 0;

  for (const auto &r : repos) {
    total_errors += r.findings_errors;
    total_warnings += r.findings_warnings;
    if (r.findings_errors == 0 && r.findings_warnings == 0) clean++;
  }

  printf("\n  Scan Report (%zu repos)\n", repos.size());
  printf("  ─────────────────────────────────────────────\n");
  printf("  Clean: %d | Errors: %d | Warnings: %d\n\n", clean, total_errors, total_warnings);

  // Sort by errors (worst first)
  std::vector<const Repo *> sorted;
  for (const auto &r : repos) sorted.push_back(&r);
  std::sort(sorted.begin(), sorted.end(), [](const Repo *a, const Repo *b) {
    return a->findings_errors > b->findings_errors;
  });

  // Show worst repos
  printf("  Repos with issues:\n");
  for (const auto *r : sorted) {
    if (r->findings_errors == 0 && r->findings_warnings == 0) break;
    printf("    %-40s %d errors, %d warnings\n",
           r->name.c_str(), r->findings_errors, r->findings_warnings);
  }
  printf("\n");
}

int cmd_scan(int argc, char *argv[]) {
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

  auto repos = discover_repos(opts.root_path, opts.max_depth);

  // Filter by language if specified
  if (!opts.lang_filter.empty()) {
    repos.erase(std::remove_if(repos.begin(), repos.end(), [&](const Repo &r) {
      for (const auto &l : r.languages)
        if (l.find(opts.lang_filter) != std::string::npos) return false;
      return true;
    }), repos.end());
  }

  printf("  Found %zu repos\n\n", repos.size());

  // Run checks
  for (size_t i = 0; i < repos.size(); i++) {
    int findings = run_repo_checks(repos[i], opts);
    if (findings > 0) {
      printf("  [%zu/%zu] %-40s %d findings\n", i + 1, repos.size(),
             repos[i].name.c_str(), findings);
    } else {
      printf("  [%zu/%zu] %-40s ✓\n", i + 1, repos.size(), repos[i].name.c_str());
    }
  }

  print_scan_report(repos);
  return 0;
}
