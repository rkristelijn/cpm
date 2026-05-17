/**
 * @file lockfile.cpp
 * @brief Native lockfile check — verifies reproducible builds.
 */
#include "check.h"

struct LockfileCheck : Check {
  LockfileCheck() {
    name = "lockfile";
    category = "deps";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    struct {
      const char* manifest;
      const char* locks[4];
      const char* mgr;
    } checks[] = {{"package.json", {"package-lock.json", "yarn.lock", "pnpm-lock.yaml", nullptr}, "npm/yarn/pnpm"},
                  {"Cargo.toml", {"Cargo.lock", nullptr, nullptr, nullptr}, "cargo"},
                  {"composer.json", {"composer.lock", nullptr, nullptr, nullptr}, "composer"},
                  {"go.mod", {"go.sum", nullptr, nullptr, nullptr}, "go"},
                  {"pyproject.toml", {"poetry.lock", "uv.lock", nullptr, nullptr}, "poetry/uv"},
                  {"Gemfile", {"Gemfile.lock", nullptr, nullptr, nullptr}, "bundler"},
                  {nullptr, {}, nullptr}};

    for (int i = 0; checks[i].manifest; i++) {
      if (!fs.exists(checks[i].manifest)) continue;
      bool found = false;
      for (int j = 0; checks[i].locks[j]; j++) {
        if (fs.exists(checks[i].locks[j])) {
          found = true;
          break;
        }
      }
      if (!found) {
        findings.push_back({name, "error", checks[i].manifest, 0, "missing-lockfile", std::string("No lockfile for ") + checks[i].mgr,
                            std::string("Run: ") + checks[i].mgr + " install", "https://cpm.dev/checks/lockfile"});
      }
    }
    return findings;
  }
};
