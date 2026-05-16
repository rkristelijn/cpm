/**
 * @file version_pins.cpp
 * @brief Native version pins check — detects unpinned dependencies.
 */
#include "check.h"

struct VersionPinsCheck : Check {
  VersionPinsCheck() { name = "version-pins"; category = "deps"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    /* Check package.json for ^ and ~ */
    if (fs.exists("package.json")) {
      std::string content = fs.read("package.json");
      int count = 0;
      for (size_t i = 0; i < content.size(); i++) {
        if ((content[i] == '^' || content[i] == '~') && i > 0 && content[i-1] == '"')
          count++;
      }
      if (count > 0)
        findings.push_back({name, "warning", "package.json", 0, "unpinned-npm",
            std::to_string(count) + " unpinned deps (^ or ~)",
            "Use exact versions for reproducible builds"});
    }

    /* Check Dockerfile for :latest */
    if (fs.exists("Dockerfile")) {
      std::string content = fs.read("Dockerfile");
      if (content.find(":latest") != std::string::npos)
        findings.push_back({name, "warning", "Dockerfile", 0, "latest-tag",
            "Using :latest tag", "Pin to specific version"});
    }

    /* Check GitHub Actions for unpinned actions */
    if (fs.exists(".github/workflows/ci.yml")) {
      std::string content = fs.read(".github/workflows/ci.yml");
      if (content.find("@main") != std::string::npos || content.find("@master") != std::string::npos)
        findings.push_back({name, "warning", ".github/workflows/ci.yml", 0, "unpinned-action",
            "GitHub Action pinned to branch (use SHA)", ""});
    }

    return findings;
  }
};
