/**
 * @file scan_ci.cpp
 * @brief CI/CD pipeline checks — GitLab CI, GitHub Actions.
 */
#include <cstdio>
#include <cstring>
#include <string>

#include "scan.h"
#include "scan_checks.h"

int scan_ci(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();

  std::string ci_path = repo.path + "/.gitlab-ci.yml";
  FILE* cif = fopen(ci_path.c_str(), "r");
  if (!cif) return 0;

  char cibuf[65536];
  size_t cin = fread(cibuf, 1, sizeof(cibuf) - 1, cif);
  cibuf[cin] = 0;
  fclose(cif);

  if (!strstr(cibuf, "cache")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "no-cache",
                  "No cache configured — repeated dependency downloads slow pipelines. "
                  "See: https://docs.gitlab.com/ci/caching/");
  }
  if (!strstr(cibuf, "artifacts")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "no-artifacts",
                  "No artifacts/reports — test results not visible in MR. "
                  "See: https://docs.gitlab.com/ci/testing/unit_test_reports/");
  }
  if (!strstr(cibuf, "rules") && !strstr(cibuf, "only:") && !strstr(cibuf, "workflow:")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "no-rules",
                  "No rules/workflow — pipeline runs on every push (wasteful CI minutes). "
                  "See: https://docs.gitlab.com/ci/yaml/#rules");
  }
  if (!strstr(cibuf, "timeout")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "no-timeout",
                  "No job timeout — stuck jobs block runners indefinitely. "
                  "See: https://docs.gitlab.com/ci/yaml/#timeout");
  }
  if (strstr(cibuf, "allow_failure: true") && !strstr(cibuf, "allow_failure:\n      exit_codes")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "blanket-allow-failure",
                  "allow_failure: true without exit_codes — hides real failures silently. "
                  "See: https://docs.gitlab.com/ci/yaml/#allow_failure");
  }
  if (strstr(cibuf, "include:") && strstr(cibuf, "project:") && !strstr(cibuf, "ref:")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "unpinned-include",
                  "include: project without ref: — uses default branch, breaks on upstream changes. "
                  "See: https://docs.gitlab.com/ci/yaml/#includefile");
  }
  if (strstr(cibuf, "only:") || strstr(cibuf, "except:")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "deprecated-only-except",
                  "only/except is deprecated — migrate to rules: for predictable behavior. "
                  "See: https://docs.gitlab.com/ci/yaml/#only--except");
  }
  if (!strstr(cibuf, "interruptible")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "no-interruptible",
                  "No interruptible: true — old pipelines keep running when new commits push. "
                  "See: https://docs.gitlab.com/ci/yaml/#interruptible");
  }
  if (strstr(cibuf, ":latest")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "latest-image-tag",
                  "Using :latest image tag — non-reproducible builds, breaks without warning. "
                  "See: https://docs.gitlab.com/ci/docker/using_docker_images.html");
  }
  if (strstr(cibuf, "git clone") || strstr(cibuf, "git checkout")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "git-clone-in-script",
                  "git clone/checkout in script — use artifacts or needs: to pass data between jobs. "
                  "See: https://docs.gitlab.com/ci/yaml/#needs");
  }
  if (strstr(cibuf, "export") && (strstr(cibuf, "TOKEN=") || strstr(cibuf, "PASSWORD=") || strstr(cibuf, "SECRET="))) {
    repo.findings_errors++;
    total++;
    finding_write(name, "gitlab-ci", "error", ".gitlab-ci.yml", "hardcoded-secret",
                  "Hardcoded secret in script (TOKEN/PASSWORD/SECRET) — use CI/CD variables. "
                  "See: https://docs.gitlab.com/ci/variables/");
  }

  /* Single stage = monolithic pipeline */
  {
    int stage_count = 0;
    char* s = cibuf;
    bool in_stages = false;
    while ((s = strstr(s, "\n"))) {
      s++;
      if (strncmp(s, "stages:", 7) == 0)
        in_stages = true;
      else if (in_stages && s[0] == ' ' && s[1] == ' ' && s[2] == '-')
        stage_count++;
      else if (in_stages && s[0] != ' ' && s[0] != '\n')
        in_stages = false;
    }
    if (stage_count == 1) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "gitlab-ci", "warning", ".gitlab-ci.yml", "single-stage",
                    "Only 1 stage — no fail-fast, no parallel execution possible. "
                    "See: https://docs.gitlab.com/ci/yaml/#stages");
    }
  }

  return total;
}
