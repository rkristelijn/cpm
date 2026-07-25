// cpm:exempt file-size — single logical function with all scan checks
// @see ADR-129
/**
 * @file scan_checks.cpp
 * @brief Repo quality checks — called by scan.cpp.
 */
#include <dirent.h>
#include <sys/stat.h>

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <fstream>
#include <string>
#include <vector>

#include "scan.h"
#include "../common/constants.h"

/* Portability: strcasestr is a GNU extension, not available on Windows */
#ifdef _WIN32
#define popen _popen
#define pclose _pclose
static const char* strcasestr(const char* haystack, const char* needle) {
  if (!needle[0]) return haystack;
  for (; *haystack; haystack++) {
    const char* h = haystack;
    const char* n = needle;
    while (*h && *n && (tolower((unsigned char)*h) == tolower((unsigned char)*n))) {
      h++;
      n++;
    }
    if (!*n) return haystack;
  }
  return nullptr;
}
#ifndef DT_DIR
#define DT_DIR 4
#endif
#endif

FILE* g_findings_file = nullptr;

void finding_write(const char* repo, const char* check, const char* severity, const char* file, const char* rule, const char* message) {
  if (!g_findings_file) return;
  fprintf(g_findings_file,
          "{\"repo\":\"%s\",\"check\":\"%s\",\"severity\":\"%s\","
          "\"file\":\"%s\",\"rule\":\"%s\",\"message\":\"%s\"}\n",
          repo, check, severity, file, rule, message);
}

int run_repo_checks(Repo& repo, const ScanOptions& /*opts*/) {
  int total = 0;
  const char* name = repo.name.c_str();

  // === Universal checks (any repo) ===

  // === ADR-139 Phase 1: Repo-type classification (must be first) ===
  enum RepoType { REPO_SOFTWARE, REPO_DOCS, REPO_LIST };
  RepoType repo_type = REPO_SOFTWARE;
  {
    bool has_code_dir = has_file(repo.path, "src") || has_file(repo.path, "lib") || has_file(repo.path, "app");
    bool has_build_cfg = has_file(repo.path, "package.json") || has_file(repo.path, "Cargo.toml") || has_file(repo.path, "go.mod") ||
                         has_file(repo.path, "CMakeLists.txt") || has_file(repo.path, "setup.py") ||
                         has_file(repo.path, "pyproject.toml") || has_file(repo.path, "pom.xml") || has_file(repo.path, "build.gradle");
    if (!has_code_dir && !has_build_cfg) {
      std::string cmd = "find " + shell_escape(repo.path) + " -maxdepth 2 -name '*.md' 2>/dev/null | wc -l";
      FILE* p = popen(cmd.c_str(), "r");
      if (p) {
        char b[32];
        if (fgets(b, sizeof(b), p)) {
          int md_count = atoi(b);
          if (md_count > 3) repo_type = REPO_DOCS;
        }
        pclose(p);
      }
      if (strcasestr(name, "awesome") || strcasestr(name, "list") || strcasestr(name, "curated")) repo_type = REPO_LIST;
    }
    repo.repo_type = (repo_type == REPO_SOFTWARE) ? "software" : (repo_type == REPO_DOCS) ? "docs" : "list";
  }

  // === ADR-139 Phase 1: Monorepo detection ===
  {
    bool is_monorepo = has_file(repo.path, "packages") || has_file(repo.path, "pnpm-workspace.yaml") || has_file(repo.path, "lerna.json") ||
                       has_file(repo.path, "turbo.json") || has_file(repo.path, "nx.json");
    if (!is_monorepo && has_file(repo.path, "package.json")) {
      std::string pkg = repo.path + "/package.json";
      FILE* f = fopen(pkg.c_str(), "r");
      if (f) {
        char buf[8192];
        size_t n = fread(buf, 1, sizeof(buf) - 1, f);
        buf[n] = 0;
        fclose(f);
        if (strstr(buf, "\"workspaces\"")) is_monorepo = true;
      }
    }
    repo.is_monorepo = is_monorepo;
  }

  // AI-readiness: can an AI agent work effectively in this repo?
  if (!has_file(repo.path, "CONTRIBUTING.md") && !has_file(repo.path, "contributing.md")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "ai-ready", "warning", ".", "no-contributing", "No CONTRIBUTING.md (AI agents need context to work effectively)");
  }
  // Agent config (any of: .kiro/, .amazonq/, .github/copilot-instructions.md, AGENTS.md, .cursorrules)
  if (!has_file(repo.path, ".cursorrules") && !has_file(repo.path, "AGENTS.md") &&
      !has_file(repo.path, ".github/copilot-instructions.md")) {
    // Check dirs
    std::string kiro = repo.path + "/.kiro";
    std::string amazonq = repo.path + "/.amazonq";
    struct stat st;
    if (stat(kiro.c_str(), &st) != 0 && stat(amazonq.c_str(), &st) != 0) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "ai-ready", "warning", ".", "no-agent-config", "No AI agent config (.kiro/, .amazonq/, .cursorrules, AGENTS.md)");
    }
  }

  // CI/CD pipeline detection (top platforms)
  bool has_ci = has_file(repo.path, ".github/workflows/ci.yml") || has_file(repo.path, ".github/workflows/main.yml") ||
                has_file(repo.path, ".gitlab-ci.yml") || has_file(repo.path, ".ci/.gitlab-ci.yml") ||
                has_file(repo.path, "bitbucket-pipelines.yml") || has_file(repo.path, "Jenkinsfile") ||
                has_file(repo.path, ".circleci/config.yml") || has_file(repo.path, ".travis.yml") ||
                has_file(repo.path, "azure-pipelines.yml") || has_file(repo.path, ".drone.yml") || has_file(repo.path, "buildkite.yml") ||
                has_file(repo.path, ".woodpecker.yml");
  if (!has_ci) {
    // Check for .github/workflows/ dir with any yml
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

  // Build system / task runner
  if (repo_type == REPO_SOFTWARE && !has_file(repo.path, "Makefile") && !has_file(repo.path, "makefile") &&
      !has_file(repo.path, "Taskfile.yml") && !has_file(repo.path, "justfile") && !has_file(repo.path, "package.json") &&
      !has_file(repo.path, "CMakeLists.txt") && !has_file(repo.path, "build.gradle") && !has_file(repo.path, "pom.xml") &&
      !has_file(repo.path, "Cargo.toml")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "devops", "warning", ".", "no-build-system",
                  "No build system or task runner (Makefile, package.json, CMake, etc.)");
  }

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
      // Setup: install, setup, getting started, quick start, usage, how to run
      if (strcasestr(rbuf, "install") || strcasestr(rbuf, "setup") || strcasestr(rbuf, "getting started") ||
          strcasestr(rbuf, "quick start") || strcasestr(rbuf, "how to run") || strcasestr(rbuf, "usage"))
        score++;
      // Testing: test, validate, lint, verify, check, quality
      if (strcasestr(rbuf, "test") || strcasestr(rbuf, "validate") || strcasestr(rbuf, "lint") || strcasestr(rbuf, "verify") ||
          strcasestr(rbuf, "quality"))
        score++;
      // Deploy: deploy, release, publish, ship, ci/cd, pipeline
      if (strcasestr(rbuf, "deploy") || strcasestr(rbuf, "release") || strcasestr(rbuf, "publish") || strcasestr(rbuf, "ship") ||
          strcasestr(rbuf, "ci/cd") || strcasestr(rbuf, "pipeline"))
        score++;
      // Prerequisites: prerequisite, requirement, dependencies, needs, stack
      if (strcasestr(rbuf, "prerequisite") || strcasestr(rbuf, "requirement") || strcasestr(rbuf, "dependencies") ||
          strcasestr(rbuf, "stack") || strcasestr(rbuf, "tech stack"))
        score++;
      // Contributing: contributing, development, how to contribute, pull request
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

  /**
   * @file scan_checks.cpp
   * @brief Polyrepo scanner — fast file-based quality metrics.
   *
   * Scans directories for git repos and scores them on maturity (0-5).
   * Uses only file I/O (no system() calls) to achieve <1s for 100+ repos.
   */

  /* Language-specific checks — called from run_repo_checks() */

  // === TypeScript / JavaScript ===
  for (const auto& lang : repo.languages) {
    if (lang == "typescript" || lang == "javascript") {
      /* Detect monorepo type */
      bool is_nx = has_file(repo.path, "nx.json");
      bool is_turbo = has_file(repo.path, "turbo.json");
      (void)is_nx;
      (void)is_turbo; /* used by Next.js check below */

      std::string pkg = repo.path + "/package.json";
      FILE* f = fopen(pkg.c_str(), "r");
      if (!f) continue;
      char buf[65536];
      size_t n = fread(buf, 1, sizeof(buf) - 1, f);
      buf[n] = 0;
      fclose(f);

      if (!strstr(buf, "\"test\"")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "package-json", "warning", "package.json", "no-test-script", "No test script");
      }
      if (strstr(buf, "\"^") || strstr(buf, "\"~")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "package-json", "warning", "package.json", "unpinned-deps", "Dependencies use ^ or ~");
      }
      if (!strstr(buf, "\"description\"")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "package-json", "warning", "package.json", "missing-description", "No description field");
      }
      if (!strstr(buf, "\"repository\"")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "package-json", "warning", "package.json", "missing-repository", "No repository field");
      }
      if (!has_file(repo.path, "package-lock.json") && !has_file(repo.path, "pnpm-lock.yaml") && !has_file(repo.path, "yarn.lock")) {
        repo.findings_errors++;
        total++;
        finding_write(name, "package-json", "error", ".", "no-lockfile", "No lockfile (package-lock/pnpm-lock/yarn.lock)");
      }

      /* Framework version EOL detection */
      auto check_fw = [&](const char* pkg_name, int min_major, const char* rule, const char* label, const char* upgrade_to) {
        char* pos = strstr(buf, pkg_name);
        if (!pos) return;
        /* Find version: skip to the value after colon + quote */
        char* colon = strchr(pos + strlen(pkg_name), ':');
        if (!colon) return;
        char* quote = strchr(colon, '"');
        if (!quote) return;
        quote++; /* skip opening quote */
        while (*quote && !isdigit(*quote)) quote++;
        int major = atoi(quote);
        if (major > 0 && major < min_major) {
          char msg[CPM_MSG_MAX];
          snprintf(msg, sizeof(msg), "%s %d.x is EOL — upgrade to %s", label, major, upgrade_to);
          repo.findings_warnings++;
          total++;
          finding_write(name, "framework-eol", "warning", "package.json", rule, msg);
        }
      };

      check_fw("\"react\"", 18, "react-eol", "React", "18+");
      check_fw("\"next\"", 14, "nextjs-eol", "Next.js", "14+");
      check_fw("\"@angular/core\"", 16, "angular-eol", "Angular", "16+");
      check_fw("\"vue\"", 3, "vue-eol", "Vue", "3+");
      check_fw("\"typescript\"", 5, "typescript-eol", "TypeScript", "5+");
      check_fw("\"express\"", 4, "express-eol", "Express", "4+");
      check_fw("\"@nestjs/core\"", 9, "nestjs-eol", "NestJS", "9+");
      /* Frontend */
      check_fw("\"svelte\"", 4, "svelte-eol", "Svelte", "4+");
      check_fw("\"solid-js\"", 1, "solidjs-eol", "SolidJS", "1+");
      /* Fullstack/meta */
      check_fw("\"nuxt\"", 3, "nuxt-eol", "Nuxt", "3+");
      check_fw("\"@remix-run/node\"", 2, "remix-eol", "Remix", "2+");
      check_fw("\"astro\"", 3, "astro-eol", "Astro", "3+");
      check_fw("\"@sveltejs/kit\"", 1, "sveltekit-eol", "SvelteKit", "1+");
      /* Backend */
      check_fw("\"fastify\"", 4, "fastify-eol", "Fastify", "4+");

      /* Next.js server hardening check */
      if (strstr(buf, "\"next\"")) {
        /* Extract Next.js major version for version-scoped findings */
        int next_major = 0;
        char* npos = strstr(buf, "\"next\"");
        if (npos) {
          char* nc = strchr(npos + 6, ':');
          if (nc) {
            char* nq = strchr(nc, '"');
            if (nq) {
              nq++;
              while (*nq && !isdigit(*nq)) nq++;
              next_major = atoi(nq);
            }
          }
        }

        /* Find next.config: check root, then apps for monorepos */
        std::string ncfg_path;
        if (has_file(repo.path, "next.config.ts"))
          ncfg_path = repo.path + "/next.config.ts";
        else if (has_file(repo.path, "next.config.mjs"))
          ncfg_path = repo.path + "/next.config.mjs";
        else if (has_file(repo.path, "next.config.js"))
          ncfg_path = repo.path + "/next.config.js";
        else {
          /* Monorepo: scan apps subdirs for next.config */
          std::string apps_dir = repo.path + "/apps";
          DIR* ad = opendir(apps_dir.c_str());
          if (ad) {
            struct dirent* ae;
            while ((ae = readdir(ad)) != nullptr) {
              if (ae->d_name[0] == '.') continue;
#ifdef _WIN32
              struct stat dst;
              std::string dpath = apps_dir + "/" + ae->d_name;
              if (stat(dpath.c_str(), &dst) != 0 || !S_ISDIR(dst.st_mode)) continue;
#else
              if (ae->d_type != DT_DIR) continue;
#endif
              std::string app = apps_dir + "/" + ae->d_name;
              if (has_file(app, "next.config.ts")) {
                ncfg_path = app + "/next.config.ts";
                break;
              }
              if (has_file(app, "next.config.mjs")) {
                ncfg_path = app + "/next.config.mjs";
                break;
              }
              if (has_file(app, "next.config.js")) {
                ncfg_path = app + "/next.config.js";
                break;
              }
            }
            closedir(ad);
          }
        }

        if (!ncfg_path.empty()) {
          FILE* ncf = fopen(ncfg_path.c_str(), "r");
          if (ncf) {
            char ncbuf[32768];
            size_t ncn = fread(ncbuf, 1, sizeof(ncbuf) - 1, ncf);
            ncbuf[ncn] = 0;
            fclose(ncf);

            if (!strstr(ncbuf, "poweredByHeader")) {
              repo.findings_warnings++;
              total++;
              finding_write(name, "nextjs-hardening", "warning", "next.config.ts", "no-powered-by-header",
                            "poweredByHeader not disabled — leaks framework info (Next.js 14-16: add poweredByHeader: false)");
            }
            if (!strstr(ncbuf, "headers")) {
              repo.findings_warnings++;
              total++;
              finding_write(name, "nextjs-hardening", "warning", "next.config.ts", "no-security-headers",
                            "No security headers configured (X-Frame-Options, CSP, X-Content-Type-Options)");
            }
            /* Version scope warning for unknown versions */
            if (next_major > 16) {
              repo.findings_warnings++;
              total++;
              char vmsg[CPM_MSG_MAX];
              snprintf(vmsg, sizeof(vmsg), "Next.js %d detected — hardening fix only verified for 14-16, verify config API manually",
                       next_major);
              finding_write(name, "nextjs-hardening", "warning", "next.config.ts", "nextjs-version-unverified", vmsg);
            }
          }
        }
      }
    }

    // === Node.js Runtime EOL check ===
    {
      int node_ver = 0;
      std::string nvmrc_path = repo.path + SEP + ".nvmrc";
      FILE* nf = fopen(nvmrc_path.c_str(), "r");
      if (nf) {
        char nbuf[64];
        if (fgets(nbuf, sizeof(nbuf), nf)) {
          /* Parse version: "v14.21.3" or "18.17.0" → extract major */
          char* p = nbuf;
          if (*p == 'v') p++;
          node_ver = atoi(p);
        }
        fclose(nf);
      }
      if (node_ver > 0 && node_ver < 20) {
        repo.findings_errors++;
        total++;
        char msg[CPM_MSG_MAX];
        snprintf(msg, sizeof(msg), "Node.js %d is EOL — upgrade to 20+", node_ver);
        finding_write(name, "runtime-eol", "error", ".nvmrc", "node-eol", msg);
      }
    }

    // === Java ===
    if (lang == "java") {
      if (has_file(repo.path, "pom.xml")) {
        std::string pom = repo.path + "/pom.xml";
        FILE* f = fopen(pom.c_str(), "r");
        if (f) {
          char buf[65536];
          size_t n = fread(buf, 1, sizeof(buf) - 1, f);
          buf[n] = 0;
          fclose(f);
          if (!strstr(buf, "<description>")) {
            repo.findings_warnings++;
            total++;
            finding_write(name, "pom-xml", "warning", "pom.xml", "missing-description", "No <description> in pom.xml");
          }
          if (strstr(buf, "SNAPSHOT")) {
            repo.findings_warnings++;
            total++;
            finding_write(name, "pom-xml", "warning", "pom.xml", "snapshot-deps", "SNAPSHOT dependencies found");
          }
          /* Java version EOL: < 17 is EOL */
          char* jv = strstr(buf, "<java.version>");
          if (!jv) jv = strstr(buf, "<maven.compiler.source>");
          if (jv) {
            int java_ver = atoi(jv + (strstr(jv, "<java") ? 14 : 23));
            if (java_ver > 0 && java_ver < 17) {
              repo.findings_errors++;
              total++;
              char msg[CPM_MSG_MAX];
              snprintf(msg, sizeof(msg), "Java %d is EOL — upgrade to 17+", java_ver);
              finding_write(name, "runtime-eol", "error", "pom.xml", "java-eol", msg);
            }
          }
          /* Spring Boot EOL: < 3.0 is EOL */
          char* sb = strstr(buf, "spring-boot");
          if (sb) {
            char* ver = strstr(sb, "<version>");
            if (ver) {
              int major = atoi(ver + 9);
              if (major > 0 && major < 3) {
                repo.findings_warnings++;
                total++;
                char msg[CPM_MSG_MAX];
                snprintf(msg, sizeof(msg), "Spring Boot %d.x is EOL — upgrade to 3.x", major);
                finding_write(name, "framework-eol", "warning", "pom.xml", "spring-boot-eol", msg);
              }
            }
          }
        }
      }
    }

    // === Python ===
    if (lang == "python") {
      if (!has_file(repo.path, "pyproject.toml") && !has_file(repo.path, "setup.py") && !has_file(repo.path, "setup.cfg")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "python", "warning", ".", "no-pyproject", "No pyproject.toml (modern Python standard)");
      }
      if (has_file(repo.path, "requirements.txt") && !has_file(repo.path, "requirements.lock") && !has_file(repo.path, "poetry.lock") &&
          !has_file(repo.path, "Pipfile.lock")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "python", "warning", ".", "no-lockfile", "requirements.txt without lockfile");
      }
      /* pyproject.toml manifest parsing */
      std::string pyproj = repo.path + "/pyproject.toml";
      FILE* pf = fopen(pyproj.c_str(), "r");
      if (pf) {
        char pbuf[16384];
        size_t pn = fread(pbuf, 1, sizeof(pbuf) - 1, pf);
        pbuf[pn] = 0;
        fclose(pf);
        /* Check for requires-python */
        if (!strstr(pbuf, "requires-python")) {
          repo.findings_warnings++;
          total++;
          finding_write(name, "python", "warning", "pyproject.toml", "python-no-version-constraint", "No requires-python constraint");
        }
        /* Check for formatter: tool.ruff, tool.black, or tool.autopep8 */
        if (!strstr(pbuf, "[tool.ruff]") && !strstr(pbuf, "[tool.black]") && !strstr(pbuf, "[tool.autopep8]")) {
          repo.findings_warnings++;
          total++;
          finding_write(name, "python", "warning", "pyproject.toml", "python-no-formatter",
                        "No Python formatter configured (ruff/black/autopep8)");
        }
      }
      /* Python version EOL: check .python-version */
      std::string pyver_path = repo.path + SEP + ".python-version";
      FILE* pvf = fopen(pyver_path.c_str(), "r");
      if (pvf) {
        char pbuf[32];
        if (fgets(pbuf, sizeof(pbuf), pvf)) {
          int major = 0, minor = 0;
          sscanf(pbuf, "%d.%d", &major, &minor);
          if (major == 3 && minor < 10) {
            repo.findings_errors++;
            total++;
            char msg[CPM_MSG_MAX];
            snprintf(msg, sizeof(msg), "Python 3.%d is EOL — upgrade to 3.10+", minor);
            finding_write(name, "runtime-eol", "error", ".python-version", "python-eol", msg);
          }
        }
        fclose(pvf);
      }
      /* Django/FastAPI version from pyproject.toml or requirements.txt */
      std::string pyproj2 = repo.path + "/pyproject.toml";
      std::string reqs = repo.path + "/requirements.txt";
      FILE* pyf = fopen(pyproj2.c_str(), "r");
      if (!pyf) pyf = fopen(reqs.c_str(), "r");
      if (pyf) {
        char pbuf[32768];
        size_t pn = fread(pbuf, 1, sizeof(pbuf) - 1, pyf);
        pbuf[pn] = 0;
        fclose(pyf);
        /* Django < 4.2 is EOL */
        char* dj = strstr(pbuf, "django");
        if (!dj) dj = strstr(pbuf, "Django");
        if (dj) {
          char* p = dj;
          while (*p && !isdigit(*p)) p++;
          int dj_major = atoi(p);
          if (dj_major > 0 && dj_major < 4) {
            repo.findings_warnings++;
            total++;
            char msg[CPM_MSG_MAX];
            snprintf(msg, sizeof(msg), "Django %d.x is EOL — upgrade to 4.2+", dj_major);
            finding_write(name, "framework-eol", "warning", "pyproject.toml", "django-eol", msg);
          }
        }
      }
    }

    // === PHP ===
    if (lang == "php") {
      if (has_file(repo.path, "composer.json")) {
        if (!has_file(repo.path, "composer.lock")) {
          repo.findings_errors++;
          total++;
          finding_write(name, "composer", "error", ".", "no-lockfile", "No composer.lock");
        }
        std::string cj = repo.path + "/composer.json";
        FILE* f = fopen(cj.c_str(), "r");
        if (f) {
          char buf[65536];
          size_t n = fread(buf, 1, sizeof(buf) - 1, f);
          buf[n] = 0;
          fclose(f);
          if (!strstr(buf, "\"description\"")) {
            repo.findings_warnings++;
            total++;
            finding_write(name, "composer", "warning", "composer.json", "missing-description", "No description");
          }
          /* Laravel EOL: < 10 is EOL */
          char* lv = strstr(buf, "\"laravel/framework\"");
          if (lv) {
            char* colon = strchr(lv + 19, ':');
            if (colon) {
              char* q = strchr(colon, '"');
              if (q) {
                q++;
                while (*q && !isdigit(*q)) q++;
              }
              int major = q ? atoi(q) : 0;
              if (major > 0 && major < 10) {
                repo.findings_warnings++;
                total++;
                char msg[CPM_MSG_MAX];
                snprintf(msg, sizeof(msg), "Laravel %d.x is EOL — upgrade to 10+", major);
                finding_write(name, "framework-eol", "warning", "composer.json", "laravel-eol", msg);
              }
            }
          }
          /* PHP version EOL: < 8.2 */
          char* php_req = strstr(buf, "\"php\"");
          if (php_req) {
            char* colon = strchr(php_req + 5, ':');
            if (colon) {
              char* q = strchr(colon, '"');
              if (q) {
                q++;
                while (*q && !isdigit(*q)) q++;
              }
              int major = q ? atoi(q) : 0;
              int minor = 0;
              if (q && strchr(q, '.')) minor = atoi(strchr(q, '.') + 1);
              if (major == 7 || (major == 8 && minor < 2)) {
                repo.findings_errors++;
                total++;
                char msg[CPM_MSG_MAX];
                snprintf(msg, sizeof(msg), "PHP %d.%d is EOL — upgrade to 8.2+", major, minor);
                finding_write(name, "runtime-eol", "error", "composer.json", "php-eol", msg);
              }
            }
          }
        }
      }
    }

    // === Go ===
    if (lang == "go") {
      if (!has_file(repo.path, "go.sum")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "go", "warning", ".", "no-go-sum", "No go.sum (run go mod tidy)");
      }
      /* go.mod manifest parsing */
      std::string gomod = repo.path + "/go.mod";
      FILE* gf = fopen(gomod.c_str(), "r");
      if (gf) {
        char gbuf[8192];
        size_t gn = fread(gbuf, 1, sizeof(gbuf) - 1, gf);
        gbuf[gn] = 0;
        fclose(gf);
        /* Check for 'go' directive */
        char* go_directive = strstr(gbuf, "go ");
        if (!go_directive) {
          repo.findings_warnings++;
          total++;
          finding_write(name, "go", "warning", "go.mod", "no-go-directive", "No 'go' directive in go.mod");
        } else {
          /* Parse version: go 1.XX */
          char* ver = go_directive + 3;
          while (*ver && !isdigit(*ver)) ver++;
          if (*ver == '1') {
            char* dot = strchr(ver, '.');
            if (dot) {
              int minor = atoi(dot + 1);
              if (minor > 0 && minor < 22) {
                repo.findings_errors++;
                total++;
                char msg[CPM_MSG_MAX];
                snprintf(msg, sizeof(msg), "Go 1.%d is EOL — upgrade to 1.22+", minor);
                finding_write(name, "go", "error", "go.mod", "go-version-eol", msg);
              }
            }
          }
        }
      }
    }

    // === Rust ===
    if (lang == "rust") {
      if (!has_file(repo.path, "Cargo.lock")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "cargo", "warning", ".", "no-cargo-lock", "No Cargo.lock (pin deps for binaries)");
      }
      /* Cargo.toml manifest parsing */
      std::string cargo = repo.path + "/Cargo.toml";
      FILE* cf = fopen(cargo.c_str(), "r");
      if (cf) {
        char cbuf[16384];
        size_t cn = fread(cbuf, 1, sizeof(cbuf) - 1, cf);
        cbuf[cn] = 0;
        fclose(cf);
        /* Check edition */
        char* edition = strstr(cbuf, "edition");
        if (edition) {
          char* eq = strchr(edition, '=');
          if (eq) {
            char* quote = strchr(eq, '"');
            if (quote) {
              int edition_year = atoi(quote + 1);
              if (edition_year > 0 && edition_year < 2021) {
                repo.findings_warnings++;
                total++;
                char msg[CPM_MSG_MAX];
                snprintf(msg, sizeof(msg), "Rust edition %d is outdated — upgrade to 2021+", edition_year);
                finding_write(name, "rust", "warning", "Cargo.toml", "rust-edition-outdated", msg);
              }
            }
          }
        }
      }
      /* Count unsafe blocks in src/ */
      std::string src_dir = repo.path + "/src";
      std::string cmd =
          "find " + shell_escape(src_dir) + " -name '*.rs' -exec grep -c 'unsafe' {} \\; 2>/dev/null | awk '{s+=$1} END {print s+0}'";
      FILE* uf = popen(cmd.c_str(), "r");
      if (uf) {
        char ubuf[32];
        if (fgets(ubuf, sizeof(ubuf), uf)) {
          int unsafe_count = atoi(ubuf);
          if (unsafe_count > 5) {
            repo.findings_warnings++;
            total++;
            char msg[CPM_MSG_MAX];
            snprintf(msg, sizeof(msg), "High unsafe usage: %d blocks found", unsafe_count);
            finding_write(name, "rust", "warning", "src/", "rust-unsafe-heavy", msg);
          }
        }
        pclose(uf);
      }
    }

    // === Terraform / IaC ===
    if (has_file(repo.path, "main.tf") || has_file(repo.path, "terragrunt.hcl")) {
      if (!has_file(repo.path, ".terraform.lock.hcl")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "terraform", "warning", ".", "no-tf-lock", "No .terraform.lock.hcl");
      }
      /* Terraform version EOL: check versions.tf or main.tf for required_version */
      std::string vf = repo.path + "/versions.tf";
      if (!has_file(repo.path, "versions.tf")) vf = repo.path + "/main.tf";
      FILE* tf = fopen(vf.c_str(), "r");
      if (tf) {
        char tbuf[16384];
        size_t tn = fread(tbuf, 1, sizeof(tbuf) - 1, tf);
        tbuf[tn] = 0;
        fclose(tf);
        char* rv = strstr(tbuf, "required_version");
        if (rv) {
          /* Extract version: required_version = ">= 1.3.0" */
          char* p = rv;
          while (*p && !isdigit(*p)) p++;
          int major = atoi(p);
          int minor = 0;
          if (strchr(p, '.')) minor = atoi(strchr(p, '.') + 1);
          if (major == 0 || (major == 1 && minor < 5)) {
            repo.findings_warnings++;
            total++;
            char msg[CPM_MSG_MAX];
            snprintf(msg, sizeof(msg), "Terraform %d.%d is EOL — upgrade to 1.5+ (or OpenTofu)", major, minor);
            finding_write(name, "framework-eol", "warning", "versions.tf", "terraform-eol", msg);
          }
        }
        /* Terragrunt version from terragrunt.hcl */
        if (has_file(repo.path, "terragrunt.hcl")) {
          std::string tg = repo.path + "/terragrunt.hcl";
          FILE* tgf = fopen(tg.c_str(), "r");
          if (tgf) {
            char tgbuf[8192];
            size_t tgn = fread(tgbuf, 1, sizeof(tgbuf) - 1, tgf);
            tgbuf[tgn] = 0;
            fclose(tgf);
            char* tv = strstr(tgbuf, "terragrunt_version_constraint");
            if (tv) {
              char* p = tv;
              while (*p && !isdigit(*p)) p++;
              int tg_minor = 0;
              if (*p == '0' && strchr(p, '.')) tg_minor = atoi(strchr(p, '.') + 1);
              if (tg_minor > 0 && tg_minor < 50) {
                repo.findings_warnings++;
                total++;
                finding_write(name, "framework-eol", "warning", "terragrunt.hcl", "terragrunt-eol",
                              "Terragrunt 0.x < 0.50 is outdated — upgrade");
              }
            }
          }
        }
      }
    }

    // === C++ ===
    if (lang == "cpp") {
      if (!has_file(repo.path, ".clang-format") && !has_file(repo.path, ".config/.clang-format")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "cpp", "warning", ".", "no-clang-format", "No .clang-format config");
      }
      if (!has_file(repo.path, "CMakeLists.txt") && !has_file(repo.path, "Makefile")) {
        repo.findings_warnings++;
        total++;
        finding_write(name, "cpp", "warning", ".", "no-build-system", "No CMakeLists.txt or Makefile");
      }
    }
  }

  // === GitLab CI checks ===
  {
    std::string ci_path = repo.path + "/.gitlab-ci.yml";
    FILE* cif = fopen(ci_path.c_str(), "r");
    if (cif) {
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
      /* Check for inline secrets in scripts */
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
    }
  }

  // === Universal quick checks (all langs) ===

  // No tests detected
  if (repo_type == REPO_SOFTWARE) {
    bool has_tests =
        has_file(repo.path, "tests") || has_file(repo.path, "test") || has_file(repo.path, "__tests__") || has_file(repo.path, "spec");
    // Also check for test files in src
    if (!has_tests && repo.is_monorepo) {
      // Monorepo: check packages/ subdirs for tests
      std::string cmd =
          "find " + shell_escape(repo.path) +
          "/packages -maxdepth 3 -name '*.test.*' -o -name '*_test.*' -o -name 'test_*' -o -type d -name 'test' -o -type d -name 'tests' "
          "2>/dev/null | head -1";
      FILE* p = popen(cmd.c_str(), "r");
      if (p) {
        char b[CPM_MSG_MAX];
        if (fgets(b, sizeof(b), p) && b[0]) has_tests = true;
        pclose(p);
      }
    }
    if (!has_tests) {
      std::string cmd =
          "find " + shell_escape(repo.path) + " -maxdepth 3 -name '*.test.*' -o -name '*_test.*' -o -name 'test_*' 2>/dev/null | head -1";
      FILE* p = popen(cmd.c_str(), "r");
      if (p) {
        char b[CPM_MSG_MAX];
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

  // Stale repo: last commit > 12 months
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
          char msg[CPM_MSG_MAX];
          snprintf(msg, sizeof(msg), "Last commit %ld months ago — consider archiving", months);
          finding_write(name, "freshness", "warning", ".", "stale-repo", msg);
        }
      }
      pclose(p);
    }
  }

  // Large repo without .gitignore
  if (!has_file(repo.path, ".gitignore")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "devops", "warning", ".", "no-gitignore", "No .gitignore — likely committing build artifacts");
  }

  // === Git history checks: churn, bus factor, commit health ===
  if (repo_type == REPO_SOFTWARE) {
    // Bus factor: how many unique authors in last 6 months?
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
                        "Only 1 active contributor in last 6 months — knowledge concentration risk");
        }
      }
      pclose(pa);
    }

    // Churn hotspot: files changed >20 times in last 3 months (high risk)
    std::string cmd_churn = "git -C " + shell_escape(repo.path) +
                            " log --since='3 months ago' --name-only --pretty=format: 2>/dev/null"
                            " | sort | uniq -c | sort -rn | head -1";
    FILE* pc = popen(cmd_churn.c_str(), "r");
    if (pc) {
      char b[CPM_LINE_MAX];
      if (fgets(b, sizeof(b), pc)) {
        int changes = atoi(b);
        if (changes > 20) {
          // Extract filename
          char* fname = b;
          while (*fname == ' ' || isdigit(*fname)) fname++;
          if (*fname) {
            char* nl = strchr(fname, '\n');
            if (nl) *nl = 0;
            char safe_fname[CPM_PATH_MAX];
            strncpy(safe_fname, fname, sizeof(safe_fname) - 1);
            safe_fname[sizeof(safe_fname) - 1] = '\0';
            char msg[CPM_MSG_MAX];
            snprintf(msg, sizeof(msg), "High churn: %s changed %d times in 3 months — refactor candidate", safe_fname, changes);
            repo.findings_warnings++;
            total++;
            finding_write(name, "git-health", "warning", fname, "high-churn", msg);
          }
        }
      }
      pclose(pc);
    }

    // Large commits: any commit touching >50 files in last month (code dump risk)
    // Skip for shallow clones (initial commit contains all files)
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
            char msg[CPM_MSG_MAX];
            snprintf(msg, sizeof(msg), "Large commit detected: %d files in one commit — review for code dumps", files_changed);
            repo.findings_warnings++;
            total++;
            finding_write(name, "git-health", "warning", ".", "large-commit", msg);
          }
        }
        pclose(pl);
      }
    }
  }

  // === ADR-139 Phase 1: .editorconfig presence ===
  if (repo_type == REPO_SOFTWARE && !has_file(repo.path, ".editorconfig")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "standards", "warning", ".", "no-editorconfig",
                  "No .editorconfig — editor-agnostic formatting not enforced (48% of top repos have one)");
  }

  // === ADR-139 Phase 1: SECURITY.md presence ===
  if (!has_file(repo.path, "SECURITY.md") && !has_file(repo.path, ".github/SECURITY.md")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "standards", "warning", ".", "no-security-policy",
                  "No SECURITY.md — no vulnerability disclosure policy (34% of top repos have one)");
  }

  // === ADR-139 Phase 1: Issue/PR templates ===
  if (repo_type == REPO_SOFTWARE) {
    struct stat st;
    std::string issue_dir = repo.path + "/.github/ISSUE_TEMPLATE";
    std::string gitlab_issue = repo.path + "/.gitlab/issue_templates";
    if (stat(issue_dir.c_str(), &st) != 0 && stat(gitlab_issue.c_str(), &st) != 0) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "standards", "warning", ".", "no-issue-templates",
                    "No issue templates — inconsistent bug reports (66% of top repos have them)");
    }
    std::string pr_tmpl = repo.path + "/.github/pull_request_template.md";
    std::string pr_tmpl2 = repo.path + "/.github/PULL_REQUEST_TEMPLATE.md";
    std::string gl_mr = repo.path + "/.gitlab/merge_request_templates";
    if (stat(pr_tmpl.c_str(), &st) != 0 && stat(pr_tmpl2.c_str(), &st) != 0 && stat(gl_mr.c_str(), &st) != 0) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "standards", "warning", ".", "no-pr-template",
                    "No PR/MR template — inconsistent pull requests (66% of top repos have one)");
    }
  }

  // Secrets in plain sight: .env tracked in git
  {
    std::string cmd = "git -C " + shell_escape(repo.path) + " ls-files .env 2>/dev/null | head -1";
    FILE* p = popen(cmd.c_str(), "r");
    if (p) {
      char b[CPM_MSG_MAX];
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
