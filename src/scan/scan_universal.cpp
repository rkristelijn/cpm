/**
 * @file scan_universal.cpp
 * @brief Universal checks: docs, standards, testing, git health, secrets.
 *
 * These checks apply to all repos regardless of language.
 * Extracted from the monolithic scan_checks.cpp as part of ADR-139.
 */
#include <sys/stat.h>

#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>

#include "../common/compat.h"
#include "../common/constants.h"
#include "scan.h"
#include "scan_checks.h"

int scan_universal(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();
  bool is_software = (repo.repo_type == "software");

  /* --- Docs & community --- */

  if (!has_file(repo.path, "CONTRIBUTING.md") && !has_file(repo.path, "contributing.md")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "ai-ready", "warning", ".", "no-contributing", "No CONTRIBUTING.md (AI agents need context to work effectively)");
  }

  // Agent config (any of: .kiro/, .amazonq/, .github/copilot-instructions.md, AGENTS.md, .cursorrules)
  if (!has_file(repo.path, ".cursorrules") && !has_file(repo.path, "AGENTS.md") &&
      !has_file(repo.path, ".github/copilot-instructions.md")) {
    std::string kiro = repo.path + "/.kiro";
    std::string amazonq = repo.path + "/.amazonq";
    struct stat st;
    if (stat(kiro.c_str(), &st) != 0 && stat(amazonq.c_str(), &st) != 0) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "ai-ready", "warning", ".", "no-agent-config", "No AI agent config (.kiro/, .amazonq/, .cursorrules, AGENTS.md)");
    }
  }

  /* --- CI/CD pipeline detection --- */

  bool has_ci = has_file(repo.path, ".github/workflows/ci.yml") || has_file(repo.path, ".github/workflows/main.yml") ||
                has_file(repo.path, ".gitlab-ci.yml") || has_file(repo.path, ".ci/.gitlab-ci.yml") ||
                has_file(repo.path, "bitbucket-pipelines.yml") || has_file(repo.path, "Jenkinsfile") ||
                has_file(repo.path, ".circleci/config.yml") || has_file(repo.path, ".travis.yml") ||
                has_file(repo.path, "azure-pipelines.yml") || has_file(repo.path, ".drone.yml") || has_file(repo.path, "buildkite.yml") ||
                has_file(repo.path, ".woodpecker.yml");
  if (!has_ci) {
    std::string ghdir = repo.path + "/.github/workflows";
    struct stat st;
    if (stat(ghdir.c_str(), &st) == 0 && S_ISDIR(st.st_mode)) has_ci = true;
  }
  if (!has_ci) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "devops", "warning", ".", "no-ci-pipeline",
                  "No CI/CD pipeline detected (GitHub Actions, GitLab CI, Jenkins, etc.)");
  }

  /* --- Build system / task runner --- */

  if (is_software && !has_file(repo.path, "Makefile") && !has_file(repo.path, "makefile") && !has_file(repo.path, "Taskfile.yml") &&
      !has_file(repo.path, "justfile") && !has_file(repo.path, "package.json") && !has_file(repo.path, "CMakeLists.txt") &&
      !has_file(repo.path, "build.gradle") && !has_file(repo.path, "pom.xml") && !has_file(repo.path, "Cargo.toml")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "devops", "warning", ".", "no-build-system",
                  "No build system or task runner (Makefile, package.json, CMake, etc.)");
  }

  /* --- License & README --- */

  if (!has_file(repo.path, "LICENSE") && !has_file(repo.path, "LICENSE.md") && !has_file(repo.path, "LICENCE")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "community", "warning", ".", "missing-license", "No LICENSE file");
  }

  if (!has_file(repo.path, "README.md") && !has_file(repo.path, "readme.md")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "community", "warning", ".", "missing-readme", "No README.md");
  } else {
    std::string readme_path = has_file(repo.path, "README.md") ? repo.path + "/README.md" : repo.path + "/readme.md";
    FILE* rf = fopen(readme_path.c_str(), "r");
    if (rf) {
      char rbuf[65536];
      size_t rn = fread(rbuf, 1, sizeof(rbuf) - 1, rf);
      rbuf[rn] = 0;
      fclose(rf);

      // Default template detection
      if (strstr(rbuf, "Getting started with GitLab") || strstr(rbuf, "# project-name") || strstr(rbuf, "Edit this README")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "readme-audit", "warning", "README.md", "default-readme", "README is still the default template");
      }

      // Section scoring (aliases for same concept)
      int score = 0;
      if (strcasestr(rbuf, "install") || strcasestr(rbuf, "setup") || strcasestr(rbuf, "getting started") ||
          strcasestr(rbuf, "quick start") || strcasestr(rbuf, "how to run") || strcasestr(rbuf, "usage"))
        score++;
      if (strcasestr(rbuf, "test") || strcasestr(rbuf, "validate") || strcasestr(rbuf, "lint") || strcasestr(rbuf, "verify") ||
          strcasestr(rbuf, "quality"))
        score++;
      if (strcasestr(rbuf, "deploy") || strcasestr(rbuf, "release") || strcasestr(rbuf, "publish") || strcasestr(rbuf, "ship") ||
          strcasestr(rbuf, "ci/cd") || strcasestr(rbuf, "pipeline"))
        score++;
      if (strcasestr(rbuf, "prerequisite") || strcasestr(rbuf, "requirement") || strcasestr(rbuf, "dependencies") ||
          strcasestr(rbuf, "stack") || strcasestr(rbuf, "tech stack"))
        score++;
      if (strcasestr(rbuf, "contribut") || strcasestr(rbuf, "development") || strcasestr(rbuf, "pull request") || strcasestr(rbuf, "PR"))
        score++;

      if (score < 2) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "readme-audit", "warning", "README.md", "low-readme-score",
                      "README missing key sections (setup/test/deploy/prerequisites/contributing)");
      }
    }
  }

  /* --- Testing detection --- */

  if (is_software) {
    bool has_tests =
        has_file(repo.path, "tests") || has_file(repo.path, "test") || has_file(repo.path, "__tests__") || has_file(repo.path, "spec");
    if (!has_tests && repo.is_monorepo) {
      std::string cmd = "find " + shell_escape(repo.path) +
                        "/packages -maxdepth 3 -name '*.test.*' -o -name '*_test.*' -o -name 'test_*'"
                        " -o -type d -name 'test' -o -type d -name 'tests' 2>/dev/null | head -1";
      FILE* p = popen(cmd.c_str(), "r");
      if (p) {
        char b[256];
        if (fgets(b, sizeof(b), p) && b[0]) has_tests = true;
        pclose(p);
      }
    }
    if (!has_tests) {
      std::string cmd = "find " + shell_escape(repo.path) +
                        " -maxdepth 3 -name '*.test.*' -o -name '*_test.*' -o -name 'test_*'"
                        " 2>/dev/null | head -1";
      FILE* p = popen(cmd.c_str(), "r");
      if (p) {
        char b[256];
        if (fgets(b, sizeof(b), p) && b[0]) has_tests = true;
        pclose(p);
      }
    }
    if (!has_tests) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "testing", "warning", ".", "no-tests", "No test directory or test files found");
    }
  }

  /* --- Staleness & git hygiene --- */

  {
    std::string cmd = "git -C " + shell_escape(repo.path) + " log -1 --format=%ct 2>/dev/null";
    FILE* p = popen(cmd.c_str(), "r");
    if (p) {
      char b[32];
      if (fgets(b, sizeof(b), p)) {
        long ts = atol(b);
        long now_ts = time(nullptr);
        long months = (now_ts - ts) / (30 * 86400);
        if (months > 12) {
          repo.findings_warnings++;
          total++;
          char msg[128];
          snprintf(msg, sizeof(msg), "Last commit %ld months ago — consider archiving", months);
          finding_write(name, "freshness", "warning", ".", "stale-repo", msg);
        }
      }
      pclose(p);
    }
  }

  if (!has_file(repo.path, ".gitignore")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "devops", "warning", ".", "no-gitignore", "No .gitignore — likely committing build artifacts");
  }

  /* --- Git history checks: churn, bus factor, commit health --- */

  if (is_software) {
    // Bus factor
    std::string cmd_authors = "git -C " + shell_escape(repo.path) + " shortlog -sn --since='6 months ago' 2>/dev/null | wc -l";
    FILE* pa = popen(cmd_authors.c_str(), "r");
    if (pa) {
      char b[32];
      if (fgets(b, sizeof(b), pa)) {
        int authors = atoi(b);
        if (authors == 1) {
          repo.findings_warnings++;
          total++;
          finding_write(name, "git-health", "warning", ".", "lottery-factor-1",
                        "Only 1 active contributor in last 6 months — "
                        "knowledge concentration risk");
        }
      }
      pclose(pa);
    }

    // Churn hotspot
    std::string cmd_churn = "git -C " + shell_escape(repo.path) +
                            " log --since='3 months ago' --name-only --pretty=format: 2>/dev/null"
                            " | sort | uniq -c | sort -rn | head -1";
    FILE* pc = popen(cmd_churn.c_str(), "r");
    if (pc) {
      char b[512];
      if (fgets(b, sizeof(b), pc)) {
        int changes = atoi(b);
        if (changes > 20) {
          char* fname = b;
          while (*fname == ' ' || isdigit(*fname)) fname++;
          if (*fname) {
            char* nl = strchr(fname, '\n');
            if (nl) *nl = 0;
            char msg[CPM_MSG_MAX];
            snprintf(msg, sizeof(msg),
                     "High churn: %s changed %d times in 3 months — "
                     "refactor candidate",
                     fname, changes);
            repo.findings_warnings++;
            total++;
            finding_write(name, "git-health", "warning", fname, "high-churn", msg);
          }
        }
      }
      pclose(pc);
    }

    // Large commits (skip shallow clones)
    std::string shallow_check = repo.path + "/.git/shallow";
    struct stat shallow_st;
    if (stat(shallow_check.c_str(), &shallow_st) != 0) {
      std::string cmd_large = "git -C " + shell_escape(repo.path) +
                              " log --since='1 month ago' --pretty=format:'%h' --shortstat 2>/dev/null"
                              " | grep -E '[0-9]+ files? changed' | awk '{print $1}' | sort -rn | head -1";
      FILE* pl = popen(cmd_large.c_str(), "r");
      if (pl) {
        char b[32];
        if (fgets(b, sizeof(b), pl)) {
          int files_changed = atoi(b);
          if (files_changed > 50) {
            char msg[128];
            snprintf(msg, sizeof(msg),
                     "Large commit detected: %d files in one commit — "
                     "review for code dumps",
                     files_changed);
            repo.findings_warnings++;
            total++;
            finding_write(name, "git-health", "warning", ".", "large-commit", msg);
          }
        }
        pclose(pl);
      }
    }
  }

  /* --- Standards: editorconfig, security policy, templates --- */

  if (is_software && !has_file(repo.path, ".editorconfig")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "standards", "warning", ".", "no-editorconfig",
                  "No .editorconfig — editor-agnostic formatting not enforced "
                  "(48% of top repos have one)");
  }

  if (!has_file(repo.path, "SECURITY.md") && !has_file(repo.path, ".github/SECURITY.md")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "standards", "warning", ".", "no-security-policy",
                  "No SECURITY.md — no vulnerability disclosure policy "
                  "(34% of top repos have one)");
  }

  if (is_software) {
    struct stat st;
    std::string issue_dir = repo.path + "/.github/ISSUE_TEMPLATE";
    std::string gitlab_issue = repo.path + "/.gitlab/issue_templates";
    if (stat(issue_dir.c_str(), &st) != 0 && stat(gitlab_issue.c_str(), &st) != 0) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "standards", "warning", ".", "no-issue-templates",
                    "No issue templates — inconsistent bug reports "
                    "(66% of top repos have them)");
    }
    std::string pr_tmpl = repo.path + "/.github/pull_request_template.md";
    std::string pr_tmpl2 = repo.path + "/.github/PULL_REQUEST_TEMPLATE.md";
    std::string gl_mr = repo.path + "/.gitlab/merge_request_templates";
    if (stat(pr_tmpl.c_str(), &st) != 0 && stat(pr_tmpl2.c_str(), &st) != 0 && stat(gl_mr.c_str(), &st) != 0) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "standards", "warning", ".", "no-pr-template",
                    "No PR/MR template — inconsistent pull requests "
                    "(66% of top repos have one)");
    }
  }

  /* --- Secrets in plain sight --- */

  {
    std::string cmd = "git -C " + shell_escape(repo.path) + " ls-files .env 2>/dev/null | head -1";
    FILE* p = popen(cmd.c_str(), "r");
    if (p) {
      char b[256];
      if (fgets(b, sizeof(b), p) && b[0] && b[0] != '\n') {
        repo.findings_warnings++;
        total++;
        finding_write(name, "security", "warning", ".env", "env-committed", ".env file tracked in git — likely contains secrets");
      }
      pclose(p);
    }
  }

  return total;
}
