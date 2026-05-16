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

// Central findings file
static FILE *g_findings_file = nullptr;

static void finding_write(const char *repo, const char *check, const char *severity,
                          const char *file, const char *rule, const char *message) {
  if (!g_findings_file) return;
  fprintf(g_findings_file,
          "{\"repo\":\"%s\",\"check\":\"%s\",\"severity\":\"%s\","
          "\"file\":\"%s\",\"rule\":\"%s\",\"message\":\"%s\"}\n",
          repo, check, severity, file, rule, message);
}

int run_repo_checks(Repo &repo, const ScanOptions &opts) {
  int total = 0;
  const char *name = repo.name.c_str();

  // === Universal checks (any repo) ===

  if (!has_file(repo.path, "LICENSE") && !has_file(repo.path, "LICENSE.md") &&
      !has_file(repo.path, "LICENCE")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "community", "warning", ".", "missing-license", "No LICENSE file");
  }

  if (!has_file(repo.path, "README.md") && !has_file(repo.path, "readme.md")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "community", "warning", ".", "missing-readme", "No README.md");
  } else {
    std::string readme_path = has_file(repo.path, "README.md")
                                  ? repo.path + "/README.md"
                                  : repo.path + "/readme.md";
    FILE *rf = fopen(readme_path.c_str(), "r");
    if (rf) {
      char rbuf[65536];
      size_t rn = fread(rbuf, 1, sizeof(rbuf) - 1, rf);
      rbuf[rn] = 0;
      fclose(rf);

      // Default template detection
      if (strstr(rbuf, "Getting started with GitLab") ||
          strstr(rbuf, "# project-name") ||
          strstr(rbuf, "Edit this README")) {
        repo.findings_warnings++; total++;
        finding_write(name, "readme-audit", "warning", "README.md", "default-readme",
                      "README is still the default template");
      }

      // Section scoring (aliases for same concept)
      int score = 0;
      // Setup: install, setup, getting started, quick start, usage, how to run
      if (strcasestr(rbuf, "install") || strcasestr(rbuf, "setup") ||
          strcasestr(rbuf, "getting started") || strcasestr(rbuf, "quick start") ||
          strcasestr(rbuf, "how to run") || strcasestr(rbuf, "usage")) score++;
      // Testing: test, validate, lint, verify, check, quality
      if (strcasestr(rbuf, "test") || strcasestr(rbuf, "validate") ||
          strcasestr(rbuf, "lint") || strcasestr(rbuf, "verify") ||
          strcasestr(rbuf, "quality")) score++;
      // Deploy: deploy, release, publish, ship, ci/cd, pipeline
      if (strcasestr(rbuf, "deploy") || strcasestr(rbuf, "release") ||
          strcasestr(rbuf, "publish") || strcasestr(rbuf, "ship") ||
          strcasestr(rbuf, "ci/cd") || strcasestr(rbuf, "pipeline")) score++;
      // Prerequisites: prerequisite, requirement, dependencies, needs, stack
      if (strcasestr(rbuf, "prerequisite") || strcasestr(rbuf, "requirement") ||
          strcasestr(rbuf, "dependencies") || strcasestr(rbuf, "stack") ||
          strcasestr(rbuf, "tech stack")) score++;
      // Contributing: contributing, development, how to contribute, pull request
      if (strcasestr(rbuf, "contribut") || strcasestr(rbuf, "development") ||
          strcasestr(rbuf, "pull request") || strcasestr(rbuf, "PR")) score++;

      if (score < 2) {
        repo.findings_warnings++; total++;
        finding_write(name, "readme-audit", "warning", "README.md", "low-readme-score",
                      "README missing key sections (setup/test/deploy/prerequisites/contributing)");
      }
    }
  }

  // === TypeScript / JavaScript ===
  for (const auto &lang : repo.languages) {
    if (lang == "typescript" || lang == "javascript") {
      std::string pkg = repo.path + "/package.json";
      FILE *f = fopen(pkg.c_str(), "r");
      if (!f) continue;
      char buf[65536];
      size_t n = fread(buf, 1, sizeof(buf) - 1, f);
      buf[n] = 0;
      fclose(f);

      if (!strstr(buf, "\"test\"")) {
        repo.findings_warnings++; total++;
        finding_write(name, "package-json", "warning", "package.json", "no-test-script", "No test script");
      }
      if (strstr(buf, "\"^") || strstr(buf, "\"~")) {
        repo.findings_warnings++; total++;
        finding_write(name, "package-json", "warning", "package.json", "unpinned-deps", "Dependencies use ^ or ~");
      }
      if (!strstr(buf, "\"description\"")) {
        repo.findings_warnings++; total++;
        finding_write(name, "package-json", "warning", "package.json", "missing-description", "No description field");
      }
      if (!strstr(buf, "\"repository\"")) {
        repo.findings_warnings++; total++;
        finding_write(name, "package-json", "warning", "package.json", "missing-repository", "No repository field");
      }
      if (!has_file(repo.path, "package-lock.json") &&
          !has_file(repo.path, "pnpm-lock.yaml") &&
          !has_file(repo.path, "yarn.lock")) {
        repo.findings_errors++; total++;
        finding_write(name, "package-json", "error", ".", "no-lockfile", "No lockfile (package-lock/pnpm-lock/yarn.lock)");
      }
    }

    // === Java ===
    if (lang == "java") {
      if (has_file(repo.path, "pom.xml")) {
        std::string pom = repo.path + "/pom.xml";
        FILE *f = fopen(pom.c_str(), "r");
        if (f) {
          char buf[65536];
          size_t n = fread(buf, 1, sizeof(buf) - 1, f);
          buf[n] = 0;
          fclose(f);
          if (!strstr(buf, "<description>")) {
            repo.findings_warnings++; total++;
            finding_write(name, "pom-xml", "warning", "pom.xml", "missing-description", "No <description> in pom.xml");
          }
          if (strstr(buf, "SNAPSHOT")) {
            repo.findings_warnings++; total++;
            finding_write(name, "pom-xml", "warning", "pom.xml", "snapshot-deps", "SNAPSHOT dependencies found");
          }
        }
      }
    }

    // === Python ===
    if (lang == "python") {
      if (!has_file(repo.path, "pyproject.toml") && !has_file(repo.path, "setup.py") &&
          !has_file(repo.path, "setup.cfg")) {
        repo.findings_warnings++; total++;
        finding_write(name, "python", "warning", ".", "no-pyproject", "No pyproject.toml (modern Python standard)");
      }
      if (has_file(repo.path, "requirements.txt") && !has_file(repo.path, "requirements.lock") &&
          !has_file(repo.path, "poetry.lock") && !has_file(repo.path, "Pipfile.lock")) {
        repo.findings_warnings++; total++;
        finding_write(name, "python", "warning", ".", "no-lockfile", "requirements.txt without lockfile");
      }
    }

    // === PHP ===
    if (lang == "php") {
      if (has_file(repo.path, "composer.json")) {
        if (!has_file(repo.path, "composer.lock")) {
          repo.findings_errors++; total++;
          finding_write(name, "composer", "error", ".", "no-lockfile", "No composer.lock");
        }
        std::string cj = repo.path + "/composer.json";
        FILE *f = fopen(cj.c_str(), "r");
        if (f) {
          char buf[65536];
          size_t n = fread(buf, 1, sizeof(buf) - 1, f);
          buf[n] = 0;
          fclose(f);
          if (!strstr(buf, "\"description\"")) {
            repo.findings_warnings++; total++;
            finding_write(name, "composer", "warning", "composer.json", "missing-description", "No description");
          }
        }
      }
    }

    // === Go ===
    if (lang == "go") {
      if (!has_file(repo.path, "go.sum")) {
        repo.findings_warnings++; total++;
        finding_write(name, "go", "warning", ".", "no-go-sum", "No go.sum (run go mod tidy)");
      }
    }

    // === Rust ===
    if (lang == "rust") {
      if (!has_file(repo.path, "Cargo.lock")) {
        repo.findings_warnings++; total++;
        finding_write(name, "cargo", "warning", ".", "no-cargo-lock", "No Cargo.lock (pin deps for binaries)");
      }
    }

    // === Terraform / IaC ===
    if (has_file(repo.path, "main.tf") || has_file(repo.path, "terragrunt.hcl")) {
      if (!has_file(repo.path, ".terraform.lock.hcl")) {
        repo.findings_warnings++; total++;
        finding_write(name, "terraform", "warning", ".", "no-tf-lock", "No .terraform.lock.hcl");
      }
    }

    // === C++ ===
    if (lang == "cpp") {
      if (!has_file(repo.path, ".clang-format") && !has_file(repo.path, ".config/.clang-format")) {
        repo.findings_warnings++; total++;
        finding_write(name, "cpp", "warning", ".", "no-clang-format", "No .clang-format config");
      }
      if (!has_file(repo.path, "CMakeLists.txt") && !has_file(repo.path, "Makefile")) {
        repo.findings_warnings++; total++;
        finding_write(name, "cpp", "warning", ".", "no-build-system", "No CMakeLists.txt or Makefile");
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

  // Open central findings file
  std::string findings_path = std::string(getenv("HOME") ? getenv("HOME") : ".") +
                              "/.local/share/cpm/scan-findings.jsonl";
  system(("mkdir -p " + findings_path.substr(0, findings_path.rfind('/'))).c_str());
  g_findings_file = fopen(findings_path.c_str(), "w"); // overwrite per scan

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

  if (g_findings_file) {
    fclose(g_findings_file);
    printf("  Findings: %s\n", findings_path.c_str());
    printf("  Query:    grep '\"severity\":\"error\"' %s\n\n", findings_path.c_str());
  }

  return 0;
}
