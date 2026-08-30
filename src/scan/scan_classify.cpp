/**
 * @file scan_classify.cpp
 * @brief Repo classification: type detection (software/docs/list) + monorepo.
 * @see ADR-139 Phase 1
 */
#include <cstdio>
#include <cstring>
#include <sys/stat.h>

#include "scan.h"
#include "scan_checks.h"

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
#endif

int scan_classify(Repo& repo) {
  const char* name = repo.name.c_str();

  /* Repo-type classification (must be first) */
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

  /* Monorepo detection */
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

  return 0; /* classification doesn't produce findings */
}
