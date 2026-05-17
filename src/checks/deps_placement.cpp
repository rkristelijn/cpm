/**
 * @file deps_placement.cpp
 * @brief Detect misplaced dependencies — dev tools in prod, prod libs in dev.
 *
 * Common mistakes:
 * - typescript, eslint, jest in dependencies (bloats production)
 * - react, express in devDependencies (breaks production)
 */
#include "check.h"

struct DepsPlacementCheck : Check {
  DepsPlacementCheck() {
    name = "deps-placement";
    category = "deps";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    if (!fs.exists("package.json")) return findings;
    std::string content = fs.read("package.json");

    /* Find dependencies and devDependencies sections */
    size_t deps_start = content.find("\"dependencies\"");
    size_t dev_start = content.find("\"devDependencies\"");
    if (deps_start == std::string::npos) return findings;

    /* Extract dependencies section */
    size_t deps_end = content.find("}", deps_start);
    std::string deps = (deps_end != std::string::npos) ? content.substr(deps_start, deps_end - deps_start) : "";

    /* Extract devDependencies section */
    std::string devdeps;
    if (dev_start != std::string::npos) {
      size_t dev_end = content.find("}", dev_start);
      devdeps = (dev_end != std::string::npos) ? content.substr(dev_start, dev_end - dev_start) : "";
    }

    /* Dev tools that should NOT be in dependencies */
    static const char* dev_only[] = {
        "typescript", "eslint",  "@eslint/",          "prettier",   "jest",       "vitest",  "mocha",       "chai",
        "sinon",      "@types/", "ts-node",           "tsx",        "nodemon",    "webpack", "vite",        "rollup",
        "esbuild",    "parcel",  "@testing-library/", "cypress",    "playwright", "husky",   "lint-staged", "commitlint",
        "jscpd",      "madge",   "depcheck",          "source-map", nullptr};

    for (int i = 0; dev_only[i]; i++) {
      if (deps.find(dev_only[i]) != std::string::npos)
        findings.push_back({name, "warning", "package.json", 0, "dev-in-prod", std::string(dev_only[i]) + " should be in devDependencies",
                            "Move to devDependencies — it bloats production bundle", ""});
    }

    /* Production libs that should NOT be in devDependencies */
    static const char* prod_only[] = {"react",    "next",          "express", "fastify", "@nestjs/core", "vue",
                                      "nuxt",     "@angular/core", "svelte",  "prisma",  "typeorm",      "sequelize",
                                      "mongoose", "dotenv",        "cors",    "helmet",  "compression",  nullptr};

    if (!devdeps.empty()) {
      for (int i = 0; prod_only[i]; i++) {
        if (devdeps.find(prod_only[i]) != std::string::npos && deps.find(prod_only[i]) == std::string::npos)
          findings.push_back({name, "error", "package.json", 0, "prod-in-dev",
                              std::string(prod_only[i]) + " in devDependencies — will be missing in production", "Move to dependencies",
                              ""});
      }
    }

    return findings;
  }
};
