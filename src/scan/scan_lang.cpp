/**
 * @file scan_lang.cpp
 * @brief Language-specific scan checks: TS/JS, Java, Python, PHP, Go, Rust, Terraform, C++.
 *
 * Design: function pointer dispatch map instead of if/else chain.
 * Each language gets its own check function. Adding a language = 1 map entry + 1 function.
 *
 * We prefer native C++ constructs (function pointers, std::unordered_map) over
 * abstract base classes, virtual dispatch, or design pattern frameworks.
 * RTFM > SOLID > code flex — keep it simple, use what the language gives you.
 * @see docs/designs/refactoring-plan.md ("Niet Doen / YAGNI")
 */
#include <dirent.h>
#include <sys/stat.h>

#include <cstdio>
#include <cstring>
#include <string>
#include <unordered_map>

#include "scan.h"
#include "scan_checks.h"

#include "../common/compat.h"

/* --- Per-language check functions ---
 * Signature: int check_<lang>(Repo& repo) → number of findings added.
 * Each function reads manifest files and checks for common issues. */

static int check_js(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();

  std::string pkg = repo.path + "/package.json";
  FILE* f = fopen(pkg.c_str(), "r");
  if (!f) return 0;
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
    char* colon = strchr(pos + strlen(pkg_name), ':');
    if (!colon) return;
    char* quote = strchr(colon, '"');
    if (!quote) return;
    quote++;
    while (*quote && !isdigit(*quote)) quote++;
    int major = atoi(quote);
    if (major > 0 && major < min_major) {
      char msg[128];
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
  check_fw("\"svelte\"", 4, "svelte-eol", "Svelte", "4+");
  check_fw("\"solid-js\"", 1, "solidjs-eol", "SolidJS", "1+");
  check_fw("\"nuxt\"", 3, "nuxt-eol", "Nuxt", "3+");
  check_fw("\"@remix-run/node\"", 2, "remix-eol", "Remix", "2+");
  check_fw("\"astro\"", 3, "astro-eol", "Astro", "3+");
  check_fw("\"@sveltejs/kit\"", 1, "sveltekit-eol", "SvelteKit", "1+");
  check_fw("\"fastify\"", 4, "fastify-eol", "Fastify", "4+");

  /* Next.js server hardening */
  if (strstr(buf, "\"next\"")) {
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

    std::string ncfg_path;
    if (has_file(repo.path, "next.config.ts"))
      ncfg_path = repo.path + "/next.config.ts";
    else if (has_file(repo.path, "next.config.mjs"))
      ncfg_path = repo.path + "/next.config.mjs";
    else if (has_file(repo.path, "next.config.js"))
      ncfg_path = repo.path + "/next.config.js";
    else {
      std::string apps_dir = repo.path + "/apps";
      DIR* ad = opendir(apps_dir.c_str());
      if (ad) {
        struct dirent* ae;
        while ((ae = readdir(ad)) != nullptr) {
          if (ae->d_name[0] == '.') continue;
          /* Use stat() everywhere: portable and more reliable than d_type,
             which returns DT_UNKNOWN on some filesystems. @see ADR-170 */
          struct stat dst;
          std::string dpath = apps_dir + "/" + ae->d_name;
          if (stat(dpath.c_str(), &dst) != 0 || !S_ISDIR(dst.st_mode)) continue;
          std::string app = apps_dir + "/" + ae->d_name;
          if (has_file(app, "next.config.ts")) { ncfg_path = app + "/next.config.ts"; break; }
          if (has_file(app, "next.config.mjs")) { ncfg_path = app + "/next.config.mjs"; break; }
          if (has_file(app, "next.config.js")) { ncfg_path = app + "/next.config.js"; break; }
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
        if (next_major > 16) {
          repo.findings_warnings++;
          total++;
          char vmsg[128];
          snprintf(vmsg, sizeof(vmsg), "Next.js %d detected — hardening fix only verified for 14-16, verify config API manually",
                   next_major);
          finding_write(name, "nextjs-hardening", "warning", "next.config.ts", "nextjs-version-unverified", vmsg);
        }
      }
    }
  }

  return total;
}

static int check_node_eol(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();
  int node_ver = 0;
  std::string nvmrc_path = repo.path + SEP + ".nvmrc";
  FILE* nf = fopen(nvmrc_path.c_str(), "r");
  if (nf) {
    char nbuf[64];
    if (fgets(nbuf, sizeof(nbuf), nf)) {
      char* p = nbuf;
      if (*p == 'v') p++;
      node_ver = atoi(p);
    }
    fclose(nf);
  }
  if (node_ver > 0 && node_ver < 20) {
    repo.findings_errors++;
    total++;
    char msg[128];
    snprintf(msg, sizeof(msg), "Node.js %d is EOL — upgrade to 20+", node_ver);
    finding_write(name, "runtime-eol", "error", ".nvmrc", "node-eol", msg);
  }
  return total;
}

static int check_java(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();
  if (!has_file(repo.path, "pom.xml")) return 0;

  std::string pom = repo.path + "/pom.xml";
  FILE* f = fopen(pom.c_str(), "r");
  if (!f) return 0;
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
  char* jv = strstr(buf, "<java.version>");
  if (!jv) jv = strstr(buf, "<maven.compiler.source>");
  if (jv) {
    int java_ver = atoi(jv + (strstr(jv, "<java") ? 14 : 23));
    if (java_ver > 0 && java_ver < 17) {
      repo.findings_errors++;
      total++;
      char msg[128];
      snprintf(msg, sizeof(msg), "Java %d is EOL — upgrade to 17+", java_ver);
      finding_write(name, "runtime-eol", "error", "pom.xml", "java-eol", msg);
    }
  }
  char* sb = strstr(buf, "spring-boot");
  if (sb) {
    char* ver = strstr(sb, "<version>");
    if (ver) {
      int major = atoi(ver + 9);
      if (major > 0 && major < 3) {
        repo.findings_warnings++;
        total++;
        char msg[128];
        snprintf(msg, sizeof(msg), "Spring Boot %d.x is EOL — upgrade to 3.x", major);
        finding_write(name, "framework-eol", "warning", "pom.xml", "spring-boot-eol", msg);
      }
    }
  }
  return total;
}

static int check_python(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();

  if (!has_file(repo.path, "pyproject.toml") && !has_file(repo.path, "setup.py") && !has_file(repo.path, "setup.cfg")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "python", "warning", ".", "no-pyproject", "No pyproject.toml (modern Python standard)");
  }
  if (has_file(repo.path, "requirements.txt") && !has_file(repo.path, "requirements.lock") &&
      !has_file(repo.path, "poetry.lock") && !has_file(repo.path, "Pipfile.lock")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "python", "warning", ".", "no-lockfile", "requirements.txt without lockfile");
  }

  std::string pyproj = repo.path + "/pyproject.toml";
  FILE* pf = fopen(pyproj.c_str(), "r");
  if (pf) {
    char pbuf[16384];
    size_t pn = fread(pbuf, 1, sizeof(pbuf) - 1, pf);
    pbuf[pn] = 0;
    fclose(pf);
    if (!strstr(pbuf, "requires-python")) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "python", "warning", "pyproject.toml", "python-no-version-constraint", "No requires-python constraint");
    }
    if (!strstr(pbuf, "[tool.ruff]") && !strstr(pbuf, "[tool.black]") && !strstr(pbuf, "[tool.autopep8]")) {
      repo.findings_warnings++;
      total++;
      finding_write(name, "python", "warning", "pyproject.toml", "python-no-formatter",
                    "No Python formatter configured (ruff/black/autopep8)");
    }
  }

  /* Python version EOL */
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
        char msg[128];
        snprintf(msg, sizeof(msg), "Python 3.%d is EOL — upgrade to 3.10+", minor);
        finding_write(name, "runtime-eol", "error", ".python-version", "python-eol", msg);
      }
    }
    fclose(pvf);
  }

  /* Django EOL */
  std::string pyproj2 = repo.path + "/pyproject.toml";
  std::string reqs = repo.path + "/requirements.txt";
  FILE* pyf = fopen(pyproj2.c_str(), "r");
  if (!pyf) pyf = fopen(reqs.c_str(), "r");
  if (pyf) {
    char pbuf[32768];
    size_t pn = fread(pbuf, 1, sizeof(pbuf) - 1, pyf);
    pbuf[pn] = 0;
    fclose(pyf);
    char* dj = strstr(pbuf, "django");
    if (!dj) dj = strstr(pbuf, "Django");
    if (dj) {
      char* p = dj;
      while (*p && !isdigit(*p)) p++;
      int dj_major = atoi(p);
      if (dj_major > 0 && dj_major < 4) {
        repo.findings_warnings++;
        total++;
        char msg[128];
        snprintf(msg, sizeof(msg), "Django %d.x is EOL — upgrade to 4.2+", dj_major);
        finding_write(name, "framework-eol", "warning", "pyproject.toml", "django-eol", msg);
      }
    }
  }
  return total;
}

static int check_php(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();
  if (!has_file(repo.path, "composer.json")) return 0;

  if (!has_file(repo.path, "composer.lock")) {
    repo.findings_errors++;
    total++;
    finding_write(name, "composer", "error", ".", "no-lockfile", "No composer.lock");
  }

  std::string cj = repo.path + "/composer.json";
  FILE* f = fopen(cj.c_str(), "r");
  if (!f) return 0;
  char buf[65536];
  size_t n = fread(buf, 1, sizeof(buf) - 1, f);
  buf[n] = 0;
  fclose(f);

  if (!strstr(buf, "\"description\"")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "composer", "warning", "composer.json", "missing-description", "No description");
  }

  /* Laravel EOL */
  char* lv = strstr(buf, "\"laravel/framework\"");
  if (lv) {
    char* colon = strchr(lv + 19, ':');
    if (colon) {
      char* q = strchr(colon, '"');
      if (q) { q++; while (*q && !isdigit(*q)) q++; }
      int major = q ? atoi(q) : 0;
      if (major > 0 && major < 10) {
        repo.findings_warnings++;
        total++;
        char msg[128];
        snprintf(msg, sizeof(msg), "Laravel %d.x is EOL — upgrade to 10+", major);
        finding_write(name, "framework-eol", "warning", "composer.json", "laravel-eol", msg);
      }
    }
  }

  /* PHP version EOL */
  char* php_req = strstr(buf, "\"php\"");
  if (php_req) {
    char* colon = strchr(php_req + 5, ':');
    if (colon) {
      char* q = strchr(colon, '"');
      if (q) { q++; while (*q && !isdigit(*q)) q++; }
      int major = q ? atoi(q) : 0;
      int minor = 0;
      if (q && strchr(q, '.')) minor = atoi(strchr(q, '.') + 1);
      if (major == 7 || (major == 8 && minor < 2)) {
        repo.findings_errors++;
        total++;
        char msg[128];
        snprintf(msg, sizeof(msg), "PHP %d.%d is EOL — upgrade to 8.2+", major, minor);
        finding_write(name, "runtime-eol", "error", "composer.json", "php-eol", msg);
      }
    }
  }
  return total;
}

static int check_go(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();

  if (!has_file(repo.path, "go.sum")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "go", "warning", ".", "no-go-sum", "No go.sum (run go mod tidy)");
  }

  std::string gomod = repo.path + "/go.mod";
  FILE* gf = fopen(gomod.c_str(), "r");
  if (!gf) return total;
  char gbuf[8192];
  size_t gn = fread(gbuf, 1, sizeof(gbuf) - 1, gf);
  gbuf[gn] = 0;
  fclose(gf);

  char* go_directive = strstr(gbuf, "go ");
  if (!go_directive) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "go", "warning", "go.mod", "no-go-directive", "No 'go' directive in go.mod");
  } else {
    char* ver = go_directive + 3;
    while (*ver && !isdigit(*ver)) ver++;
    if (*ver == '1') {
      char* dot = strchr(ver, '.');
      if (dot) {
        int minor = atoi(dot + 1);
        if (minor > 0 && minor < 22) {
          repo.findings_errors++;
          total++;
          char msg[128];
          snprintf(msg, sizeof(msg), "Go 1.%d is EOL — upgrade to 1.22+", minor);
          finding_write(name, "go", "error", "go.mod", "go-version-eol", msg);
        }
      }
    }
  }
  return total;
}

static int check_rust(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();

  if (!has_file(repo.path, "Cargo.lock")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "cargo", "warning", ".", "no-cargo-lock", "No Cargo.lock (pin deps for binaries)");
  }

  std::string cargo = repo.path + "/Cargo.toml";
  FILE* cf = fopen(cargo.c_str(), "r");
  if (cf) {
    char cbuf[16384];
    size_t cn = fread(cbuf, 1, sizeof(cbuf) - 1, cf);
    cbuf[cn] = 0;
    fclose(cf);
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
            char msg[128];
            snprintf(msg, sizeof(msg), "Rust edition %d is outdated — upgrade to 2021+", edition_year);
            finding_write(name, "rust", "warning", "Cargo.toml", "rust-edition-outdated", msg);
          }
        }
      }
    }
  }

  /* Unsafe block count */
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
        char msg[128];
        snprintf(msg, sizeof(msg), "High unsafe usage: %d blocks found", unsafe_count);
        finding_write(name, "rust", "warning", "src/", "rust-unsafe-heavy", msg);
      }
    }
    pclose(uf);
  }
  return total;
}

static int check_terraform(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();
  if (!has_file(repo.path, "main.tf") && !has_file(repo.path, "terragrunt.hcl")) return 0;

  if (!has_file(repo.path, ".terraform.lock.hcl")) {
    repo.findings_warnings++;
    total++;
    finding_write(name, "terraform", "warning", ".", "no-tf-lock", "No .terraform.lock.hcl");
  }

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
      char* p = rv;
      while (*p && !isdigit(*p)) p++;
      int major = atoi(p);
      int minor = 0;
      if (strchr(p, '.')) minor = atoi(strchr(p, '.') + 1);
      if (major == 0 || (major == 1 && minor < 5)) {
        repo.findings_warnings++;
        total++;
        char msg[128];
        snprintf(msg, sizeof(msg), "Terraform %d.%d is EOL — upgrade to 1.5+ (or OpenTofu)", major, minor);
        finding_write(name, "framework-eol", "warning", "versions.tf", "terraform-eol", msg);
      }
    }
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
  return total;
}

static int check_cpp_lang(Repo& repo) {
  int total = 0;
  const char* name = repo.name.c_str();

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
  return total;
}

/* --- Dispatch map ---
 * Native C++ function pointers — no vtable, no abstract base class, no factory.
 * RTFM > SOLID > code flex: use what the language gives you natively.
 * Adding a new language = 1 map entry + 1 static function above. */

using LangCheckFn = int (*)(Repo&);
static const std::unordered_map<std::string, LangCheckFn> lang_checkers = {
    {"typescript", check_js},
    {"javascript", check_js},
    {"java",       check_java},
    {"python",     check_python},
    {"php",        check_php},
    {"go",         check_go},
    {"rust",       check_rust},
    {"cpp",        check_cpp_lang},
};

int scan_lang(Repo& repo) {
  int total = 0;
  for (const auto& lang : repo.languages) {
    auto it = lang_checkers.find(lang);
    if (it != lang_checkers.end()) {
      total += it->second(repo);
    }
  }
  /* These run regardless of detected languages */
  total += check_node_eol(repo);
  total += check_terraform(repo);
  return total;
}
