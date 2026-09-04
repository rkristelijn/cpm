/**
// @see ADR-129
 * @file cmd_ops.cpp
 * @brief Operational commands: hooks, config, findings, reporting, git.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "../common/compat.h"
#include "../common/constants.h"
#include "../common/platform.h"
#include "../common/version.h"
#include "../scan/compliance.h"
#include "../scan/learn.h"
#include "../scan/scan.h"
#include "commands.h"
#include "runner.h"
#include "setup.h"
#include "toml.h"
#include "ui.h"

#define CPM_FILE "cpm.toml"

/* Single-quote-wrap a string for safe POSIX shell interpolation, escaping any
 * embedded single quotes via the '\'' idiom. Keeps behavior identical for
 * normal paths (which contain no quotes). @see SEC-043 */
static std::string shell_quote(const std::string& s) {
  std::string out = "'";
  for (char c : s) {
    if (c == '\'')
      out += "'\\''";
    else
      out += c;
  }
  out += "'";
  return out;
}

int cmd_hook(CpmConfig* cfg, int argc, char* argv[]) {
  /* Check for --global flag */
  bool global = false;
  const char* extra_flag = nullptr;
  for (int i = 0; i < argc; i++) {
    if (strcmp(argv[i], "--global") == 0)
      global = true;
    else if (strcmp(argv[i], "--check") == 0)
      extra_flag = "--check";
    else if (strcmp(argv[i], "--remove") == 0)
      extra_flag = "--remove";
    else if (strcmp(argv[i], "--status") == 0)
      extra_flag = "--status";
    else if (strcmp(argv[i], "--enable") == 0)
      extra_flag = "--enable";
    else if (strcmp(argv[i], "--disable") == 0)
      extra_flag = "--disable";
  }

  if (global) {
    /* Delegate to scripts/setup-global-hooks.sh relative to binary */
    std::string bin_dir = platform::executable_dir();
    /* Shell-escape the path before interpolation (SEC-043). */
    std::string qbin = shell_quote(bin_dir);
    char cmd[CPM_CMD_MAX];
    if (extra_flag && (strcmp(extra_flag, "--enable") == 0 || strcmp(extra_flag, "--disable") == 0)) {
      /* Find the check name argument after --enable/--disable */
      const char* check_name = nullptr;
      for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], extra_flag) == 0 && i + 1 < argc) {
          check_name = argv[i + 1];
          break;
        }
      }
      if (check_name) {
        /* Validate check_name against a strict allowlist before shell
         * interpolation — it comes from argv (untrusted). Only lowercase
         * letters, digits and hyphens are valid hook-check names. This closes
         * the command-injection vector (SEC-043). */
        bool valid = check_name[0] != '\0';
        for (const char* p = check_name; *p && valid; p++) {
          char c = *p;
          if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')) valid = false;
        }
        if (!valid) {
          fprintf(stderr, "cpm: invalid check name '%s' (allowed: a-z, 0-9, hyphen)\n", check_name);
          return 1;
        }
        snprintf(cmd, sizeof(cmd), "bash %s/scripts/setup-global-hooks.sh %s %s", qbin.c_str(), extra_flag, check_name);
      } else
        snprintf(cmd, sizeof(cmd), "bash %s/scripts/setup-global-hooks.sh %s", qbin.c_str(), extra_flag);
    } else if (extra_flag) {
      snprintf(cmd, sizeof(cmd), "bash %s/scripts/setup-global-hooks.sh %s", qbin.c_str(), extra_flag);
    } else {
      snprintf(cmd, sizeof(cmd), "bash %s/scripts/setup-global-hooks.sh", qbin.c_str());
    }
    return cpm_exec(cmd);
  }

  /* Per-repo hook installation (existing behavior) */
  printf("Installing git hooks...\n");
  if (cfg->hook_pre_commit) {
    if (system("mkdir -p .git/hooks && printf '#!/bin/sh\\n"
               "BRANCH=$(git rev-parse --abbrev-ref HEAD)\\n"
               "if [ \"$BRANCH\" = \"main\" ] || [ \"$BRANCH\" = \"master\" ]; then\\n"
               "  echo \"  ✗ Commit on $BRANCH blocked. Use a feature branch.\"\\n"
               "  exit 1\\n"
               "fi\\n"
               "cpm check --fast\\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit") != 0) {
      fprintf(stderr, "cpm: failed to install pre-commit hook\n");
      return 1;
    }
  }
  if (cfg->hook_pre_push) {
    if (system("mkdir -p .git/hooks && printf '#!/bin/sh\\n"
               "BRANCH=$(git rev-parse --abbrev-ref HEAD)\\n"
               "if [ \"$BRANCH\" = \"main\" ] || [ \"$BRANCH\" = \"master\" ]; then\\n"
               "  echo \"  ✗ Direct push to $BRANCH blocked. Use a feature branch.\"\\n"
               "  exit 1\\n"
               "fi\\n"
               "# Shift-left: catch Sonar issues before they reach CI\\n"
               "if [ -f checks/universal/quality/check-shift-left.sh ]; then\\n"
               "  bash checks/universal/quality/check-shift-left.sh . || exit 1\\n"
               "fi\\n"
               "cpm check\\n' > .git/hooks/pre-push && chmod +x .git/hooks/pre-push") != 0) {
      fprintf(stderr, "cpm: failed to install pre-push hook\n");
      return 1;
    }
  }
  if (cfg->hook_commit_msg) {
    if (system("mkdir -p .git/hooks && printf '#!/bin/sh\\n# conventional commit check\\n' > .git/hooks/commit-msg && chmod +x "
               ".git/hooks/commit-msg") != 0) {
      fprintf(stderr, "cpm: failed to install commit-msg hook\n");
      return 1;
    }
  }
  printf("Done.\n");
  return 0;
}

int cmd_unhook(void) {
  printf("Removing git hooks...\n");
  if (system("rm -f .git/hooks/pre-commit .git/hooks/pre-push .git/hooks/commit-msg") != 0) {
    fprintf(stderr, "cpm: failed to remove git hooks\n");
    return 1;
  }
  printf("Done.\n");
  return 0;
}

/* --- replace_in_file: portable in-place line replacement ---
 *
 * Reads file into memory, replaces the first line starting with old_prefix
 * with new_line, writes to a temp file, then renames over the original.
 * Avoids sed -i which differs between macOS and GNU.
 */
static bool replace_in_file(const char* path, const char* old_prefix, const char* new_line) {
  FILE* fp = fopen(path, "r");
  if (!fp) return false;

  char tmp_path[CPM_PATH_MAX];
  snprintf(tmp_path, sizeof(tmp_path), "%s.tmp", path);
  FILE* out = fopen(tmp_path, "w");
  if (!out) {
    fclose(fp);
    return false;
  }

  char line[1024];
  bool replaced = false;
  size_t prefix_len = strlen(old_prefix);
  while (fgets(line, sizeof(line), fp)) {
    if (!replaced && strncmp(line, old_prefix, prefix_len) == 0) {
      fprintf(out, "%s\n", new_line);
      replaced = true;
    } else {
      fputs(line, out);
    }
  }
  fclose(fp);
  fclose(out);

  if (!replaced) {
    remove(tmp_path);
    return false;
  }
  return rename(tmp_path, path) == 0;
}

/* --- bump: semantic version increment ---
 *
 * Reads current version from cpm.toml, increments the specified part,
 * writes back using portable file read-write-rename.
 */
int cmd_bump(CpmConfig* cfg, const char* part) {
  if (!part || (strcmp(part, "major") != 0 && strcmp(part, "minor") != 0 && strcmp(part, "patch") != 0)) {
    fprintf(stderr, "Usage: cpm bump <major|minor|patch>\n");
    return 1;
  }

  int major = 0, minor = 0, patch = 0;
  sscanf(cfg->version, "%d.%d.%d", &major, &minor, &patch);

  if (strcmp(part, "major") == 0) {
    major++;
    minor = 0;
    patch = 0;
  } else if (strcmp(part, "minor") == 0) {
    minor++;
    patch = 0;
  } else {
    patch++;
  }

  char newver[32];
  snprintf(newver, sizeof(newver), "%d.%d.%d", major, minor, patch);

  /* Update version in cpm.toml */
  char new_toml_line[64];
  snprintf(new_toml_line, sizeof(new_toml_line), "version = \"%s\"", newver);
  if (!replace_in_file(CPM_FILE, "version = \"", new_toml_line)) {
    fprintf(stderr, "cpm: failed to update version in %s\n", CPM_FILE);
    return 1;
  }

  /* Update CPM_VERSION in commands.h */
  char new_hdr_line[64];
  snprintf(new_hdr_line, sizeof(new_hdr_line), "#define CPM_VERSION \"%s\"", newver);
  /* Silently skip if header doesn't exist */
  FILE* hdr_test = fopen("src/commands/commands.h", "r");
  if (hdr_test) {
    fclose(hdr_test);
    if (!replace_in_file("src/commands/commands.h", "#define CPM_VERSION \"", new_hdr_line)) {
      fprintf(stderr, "cpm: failed to update CPM_VERSION in commands.h\n");
      return 1;
    }
  }

  printf("%s → %s\n", cfg->version, newver);
  return 0;
}

/* --- audit: compare installed tool versions against cpm.toml pins --- */
/* --- Version extraction helpers for audit --- */
static bool get_tool_version(const char* name, char* out, size_t outsz) {
  char cmd[256];
  /* Each tool has its own --version format */
  if (strcmp(name, "cppcheck") == 0)
    snprintf(cmd, sizeof(cmd), "cppcheck --version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+'");
  else if (strcmp(name, "cloc") == 0)
    snprintf(cmd, sizeof(cmd), "cloc --version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+'");
  else if (strcmp(name, "shellcheck") == 0)
    snprintf(cmd, sizeof(cmd), "shellcheck --version 2>/dev/null | grep '^version:' | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'");
  else if (strcmp(name, "shfmt") == 0)
    snprintf(cmd, sizeof(cmd), "shfmt --version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'");
  else if (strcmp(name, "vale") == 0)
    snprintf(cmd, sizeof(cmd), "vale --version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+'");
  else if (strcmp(name, "lychee") == 0)
    snprintf(cmd, sizeof(cmd), "lychee --version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+'");
  else if (strcmp(name, "alex") == 0)
    snprintf(cmd, sizeof(cmd), "alex --version 2>/dev/null | grep -oE '[0-9]+'");
  else if (strcmp(name, "cspell") == 0)
    snprintf(cmd, sizeof(cmd), "cspell --version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+'");
  else if (strcmp(name, "mull") == 0)
    snprintf(cmd, sizeof(cmd),
             "$(ls $(brew --prefix 2>/dev/null)/bin/mull-runner-* /usr/local/bin/mull-runner-* "
             "/usr/bin/mull-runner-* 2>/dev/null | head -1) -version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1");
  else
    snprintf(cmd, sizeof(cmd), "%s --version 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+(\\.[0-9]+)?' | head -1", name);

  FILE* p = popen(cmd, "r");
  if (!p) return false;
  out[0] = '\0';
  if (fgets(out, (int)outsz, p)) {
    /* Strip trailing newline */
    size_t len = strlen(out);
    if (len > 0 && out[len - 1] == '\n') out[len - 1] = '\0';
  }
  pclose(p);
  return out[0] != '\0';
}

/* Compare version strings: uses shared version.h */

int cmd_audit(CpmConfig* cfg) {
  printf("cpm audit — checking tool versions against cpm.toml\n\n");
  int outdated = 0, missing = 0;

  printf("  %-16s %-10s %-10s %s\n", "Tool", "Pinned", "Installed", "Status");
  printf("  %-16s %-10s %-10s %s\n", "────", "──────", "─────────", "──────");

  for (int i = 0; i < cfg->tool_count; i++) {
    char installed[64];
    if (!has_versioned_tool(cfg->tools[i].name)) {
      printf("  %-16s %-10s %-10s ✗ missing\n", cfg->tools[i].name, cfg->tools[i].version, "—");
      missing++;
    } else if (get_tool_version(cfg->tools[i].name, installed, sizeof(installed))) {
      int cmp = version_cmp(installed, cfg->tools[i].version);
      const char* status = cmp == 0 ? "✓ match" : cmp > 0 ? "↑ newer" : "↓ outdated";
      printf("  %-16s %-10s %-10s %s\n", cfg->tools[i].name, cfg->tools[i].version, installed, status);
      if (cmp < 0) outdated++;
    } else {
      printf("  %-16s %-10s %-10s ? unknown\n", cfg->tools[i].name, cfg->tools[i].version, "—");
    }
  }

  printf("\n  %d tools, %d outdated, %d missing\n", cfg->tool_count, outdated, missing);
  if (outdated > 0) printf("  Run 'cpm install' to update.\n");
  return outdated + missing > 0 ? 1 : 0;
}

/* --- get/set: read and write cpm.toml values --- */

int cmd_get(CpmConfig* cfg, const char* key) {
  if (!key) {
    /* Show all config sections */
    printf("[project]\n");
    printf("  name    = %s\n", cfg->name);
    printf("  version = %s\n", cfg->version);
    printf("  lang    = %s\n", cfg->lang);
    printf("  build   = %s\n", cfg->build);
    printf("\n[checks] (%d)\n", cfg->check_count);
    for (int i = 0; i < cfg->check_count; i++) {
      CpmCheck* c = &cfg->checks[i];
      printf("  %-20s %s%s\n", c->name, c->enabled ? "on" : "off", c->warn_only ? " (warn)" : "");
    }
    printf("\n[hooks]\n");
    printf("  pre-commit = %s\n", cfg->hook_pre_commit ? "true" : "false");
    printf("  pre-push   = %s\n", cfg->hook_pre_push ? "true" : "false");
    printf("  commit-msg = %s\n", cfg->hook_commit_msg ? "true" : "false");
    return 0;
  }

  /* Get specific key */
  if (strcmp(key, "name") == 0)
    printf("%s\n", cfg->name);
  else if (strcmp(key, "version") == 0)
    printf("%s\n", cfg->version);
  else if (strcmp(key, "lang") == 0)
    printf("%s\n", cfg->lang);
  else if (strcmp(key, "build") == 0)
    printf("%s\n", cfg->build);
  else {
    CpmCheck* c = cpm_check_find(cfg, key);
    if (c)
      printf("%s = %s%s\n", c->name, c->enabled ? "true" : "false", c->warn_only ? " (warn-only)" : "");
    else {
      fprintf(stderr, "Unknown key: %s\n", key);
      return 1;
    }
  }
  return 0;
}

int cmd_set(const char* key, const char* val) {
  if (!key || !val) {
    fprintf(stderr, "Usage: cpm set <key> <value>\n");
    return 1;
  }
  /* Rewrite cpm.toml directly — no shell interpolation (trusted-only). */
  FILE* f = fopen(CPM_FILE, "r");
  if (!f) {
    fprintf(stderr, "cpm: cannot open %s\n", CPM_FILE);
    return 1;
  }
  char tmp_path[] = "cpm.toml.cpmtmp";
  FILE* out = fopen(tmp_path, "w");
  if (!out) {
    fclose(f);
    fprintf(stderr, "cpm: cannot create temp file\n");
    return 1;
  }
  char line[2048];
  int replaced = 0;
  size_t key_len = strlen(key);
  while (fgets(line, sizeof(line), f)) {
    /* Match lines starting with "key = " or "key=" */
    if (!replaced && strncmp(line, key, key_len) == 0) {
      const char* rest = line + key_len;
      while (*rest == ' ' || *rest == '\t') rest++;
      if (*rest == '=') {
        fprintf(out, "%s = \"%s\"\n", key, val);
        replaced = 1;
        continue;
      }
    }
    fputs(line, out);
  }
  fclose(f);
  fclose(out);
  if (rename(tmp_path, CPM_FILE) != 0) {
    fprintf(stderr, "cpm: failed to update %s\n", CPM_FILE);
    remove(tmp_path);
    return 1;
  }
  printf("%s = %s\n", key, val);
  return 0;
}

/* --- JSONL finding parser (shared across output modes) --- */
struct JsonlFinding {
  char repo[128];
  char check[128];
  char sev[32];
  char msg[512];
  char rule[128];
};

static void parse_jsonl_finding(const char* line, JsonlFinding* f) {
  f->repo[0] = f->check[0] = f->sev[0] = f->msg[0] = f->rule[0] = '\0';
  const char* p;
  if ((p = strstr(line, "\"repo\":\""))) sscanf(p + 8, "%127[^\"]", f->repo);
  if ((p = strstr(line, "\"check\":\""))) sscanf(p + 9, "%127[^\"]", f->check);
  if ((p = strstr(line, "\"severity\":\""))) sscanf(p + 12, "%31[^\"]", f->sev);
  if ((p = strstr(line, "\"message\":\""))) sscanf(p + 11, "%511[^\"]", f->msg);
  if ((p = strstr(line, "\"rule\":\""))) sscanf(p + 8, "%127[^\"]", f->rule);
}

/* --- findings: query the findings database ---
 *
 * Usage:
 *   cpm findings              — show all findings
 *   cpm findings <repo>       — filter by repo name
 *   cpm findings --severity error  — filter by severity
 *   cpm findings --junit      — output as JUnit XML
 */
int cmd_findings(int argc, char* argv[]) {
  const char* home = getenv("HOME");
  if (!home) home = ".";

  /* Read from both scan and check findings (unified view) */
  const char* files[] = {"%s/.local/share/cpm/scan-findings.jsonl", "%s/.local/share/cpm/check-findings.jsonl", nullptr};
  char path[512];
  FILE* f = nullptr;

  /* Try scan findings first */
  snprintf(path, sizeof(path), files[0], home);
  f = fopen(path, "r");
  if (!f) {
    snprintf(path, sizeof(path), files[1], home);
    f = fopen(path, "r");
  }
  if (!f) {
    ui_error("No findings. Run 'cpm scan' or 'cpm check' first.");
    return 1;
  }

  /* Parse filters from args */
  const char* repo_filter = nullptr;
  const char* severity_filter = nullptr;
  const char* compliance_filter = nullptr;
  bool junit = false;
  bool learn = false;

  for (int i = 0; i < argc; i++) {
    if (strcmp(argv[i], "--severity") == 0 && i + 1 < argc) {
      severity_filter = argv[++i];
    } else if (strcmp(argv[i], "--junit") == 0) {
      junit = true;
    } else if (strcmp(argv[i], "--learn") == 0) {
      learn = true;
    } else if (strcmp(argv[i], "--compliance") == 0 && i + 1 < argc) {
      compliance_filter = argv[++i];
    } else if (argv[i][0] != '-') {
      repo_filter = argv[i];
    }
  }

  /* JUnit XML header */
  if (junit) printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<testsuites>\n<testsuite name=\"cpm-findings\">\n");

  char line[2048];
  int count = 0;
  const CpmTheme* t = ui_theme();

  while (fgets(line, sizeof(line), f)) {
    /* Quick substring filters on raw JSON (fast, no parser needed) */
    if (repo_filter && !strstr(line, repo_filter)) continue;
    if (severity_filter && !strstr(line, severity_filter)) continue;

    JsonlFinding fi;
    parse_jsonl_finding(line, &fi);

    if (junit) {
      if (strcmp(fi.sev, "error") == 0)
        printf("  <testcase name=\"%s/%s\"><failure message=\"%s\"/></testcase>\n", fi.repo, fi.check, fi.msg);
      else
        printf("  <testcase name=\"%s/%s\"><!-- %s: %s --></testcase>\n", fi.repo, fi.check, fi.sev, fi.msg);
    } else {
      /* Compliance filter: skip findings that don't match */
      if (compliance_filter) {
        auto& tags = get_compliance_tags();
        auto ct = tags.find(fi.rule);
        if (ct == tags.end() || !strstr(ct->second, compliance_filter)) continue;
      }

      const char* color = strcmp(fi.sev, "error") == 0 ? t->error : t->warning;
      printf("  %s%-7s%s %-20s %-15s %s\n", color, fi.sev, t->reset, fi.repo, fi.check, fi.msg);
      if (learn || compliance_filter) {
        if (learn) {
          auto& links = get_learn_links();
          auto it = links.find(fi.rule);
          if (it != links.end()) {
            printf("           \033[2m-> %s\033[0m %s\n", it->second.title, it->second.url);
          }
        }
        auto& tags = get_compliance_tags();
        auto ct = tags.find(fi.rule);
        if (ct != tags.end()) {
          printf("           \033[2m[%s]\033[0m\n", ct->second);
        }
      }
    }
    count++;
  }

  fclose(f);

  /* Also read check-findings if we started with scan-findings */
  char path2[512];
  snprintf(path2, sizeof(path2), files[1], home);
  FILE* f2 = fopen(path2, "r");
  if (f2) {
    while (fgets(line, sizeof(line), f2)) {
      if (repo_filter && !strstr(line, repo_filter)) continue;
      if (severity_filter && !strstr(line, severity_filter)) continue;

      JsonlFinding fi;
      parse_jsonl_finding(line, &fi);

      if (junit) {
        printf("  <testcase name=\"check/%s\"><failure message=\"%s\"/></testcase>\n", fi.check, fi.msg);
      } else {
        const char* color = strcmp(fi.sev, "error") == 0 ? t->error : t->warning;
        printf("  %s%-7s%s %-20s %-15s %s\n", color, fi.sev, t->reset, ".", fi.check, fi.msg);
      }
      count++;
    }
    fclose(f2);
  }

  if (junit)
    printf("</testsuite>\n</testsuites>\n");
  else
    printf("\n  %d finding(s)\n", count);

  return 0;
}

/* --- report: generate aggregate markdown report from findings ---
 *
 * Reads scan-findings.jsonl and produces a summary like:
 * - Total repos, findings by severity, by check category
 * - Top offenders (repos with most findings)
 * - Trend comparison (if previous report exists)
 */
int cmd_report(int argc, char* argv[]) {
  (void)argc;
  (void)argv;
  const char* home = getenv("HOME");
  if (!home) home = ".";
  char path[512];
  snprintf(path, sizeof(path), "%s/.local/share/cpm/scan-findings.jsonl", home);

  FILE* f = fopen(path, "r");
  if (!f) {
    ui_error("No findings. Run 'cpm scan' first.");
    return 1;
  }

  /* Count findings by severity and check */
  int total = 0, errors = 0, warnings = 0;
  char checks[64][128];
  int check_counts[64] = {};
  int check_count = 0;
  char repos[256][128];
  int repo_counts[256] = {};
  int repo_count = 0;

  char line[2048];
  while (fgets(line, sizeof(line), f)) {
    total++;

    /* Count severity */
    if (strstr(line, "\"error\""))
      errors++;
    else
      warnings++;

    /* Count by check */
    char check[128] = "";
    const char* cp = strstr(line, "\"check\":\"");
    if (cp) sscanf(cp + 9, "%127[^\"]", check);
    int found = 0;
    for (int i = 0; i < check_count; i++) {
      if (strcmp(checks[i], check) == 0) {
        check_counts[i]++;
        found = 1;
        break;
      }
    }
    if (!found && check_count < 64) {
      snprintf(checks[check_count], 128, "%s", check);
      check_counts[check_count] = 1;
      check_count++;
    }

    /* Count by repo */
    char repo[128] = "";
    const char* rp = strstr(line, "\"repo\":\"");
    if (rp) sscanf(rp + 8, "%127[^\"]", repo);
    found = 0;
    for (int i = 0; i < repo_count; i++) {
      if (strcmp(repos[i], repo) == 0) {
        repo_counts[i]++;
        found = 1;
        break;
      }
    }
    if (!found && repo_count < 256) {
      snprintf(repos[repo_count], 128, "%s", repo);
      repo_counts[repo_count] = 1;
      repo_count++;
    }
  }
  fclose(f);

  /* Print markdown report */
  printf("# cpm Scan Report\n\n");
  printf("Generated: %s\n\n", __DATE__);
  printf("## Summary\n\n");
  printf("| Metric | Count |\n");
  printf("|--------|-------|\n");
  printf("| **Total Repos** | %d |\n", repo_count);
  printf("| **Total Findings** | %d |\n", total);
  printf("| **Errors** | %d |\n", errors);
  printf("| **Warnings** | %d |\n", warnings);
  printf("| **Clean Repos** | %d |\n\n", repo_count > 0 ? repo_count - (int)(total > 0) : 0);

  /* Findings by check */
  printf("## Findings by Check\n\n");
  printf("| Check | Count |\n");
  printf("|-------|-------|\n");
  /* Sort by count descending (simple bubble sort) */
  for (int i = 0; i < check_count - 1; i++)
    for (int j = i + 1; j < check_count; j++)
      if (check_counts[j] > check_counts[i]) {
        int tmp = check_counts[i];
        check_counts[i] = check_counts[j];
        check_counts[j] = tmp;
        char t[128];
        memcpy(t, checks[i], 128);
        memcpy(checks[i], checks[j], 128);
        memcpy(checks[j], t, 128);
      }
  for (int i = 0; i < check_count; i++) printf("| %s | %d |\n", checks[i], check_counts[i]);

  /* Top offenders */
  printf("\n## Top Offenders\n\n");
  printf("| Repo | Findings |\n");
  printf("|------|----------|\n");
  for (int i = 0; i < repo_count - 1; i++)
    for (int j = i + 1; j < repo_count; j++)
      if (repo_counts[j] > repo_counts[i]) {
        int tmp = repo_counts[i];
        repo_counts[i] = repo_counts[j];
        repo_counts[j] = tmp;
        char t[128];
        memcpy(t, repos[i], 128);
        memcpy(repos[i], repos[j], 128);
        memcpy(repos[j], t, 128);
      }
  for (int i = 0; i < repo_count && i < 10; i++) printf("| %s | %d |\n", repos[i], repo_counts[i]);

  printf("\n---\n*Generated by cpm %s*\n", CPM_VERSION);
  return 0;
}

/* --- commit: interactive conventional commit --- */
int cmd_commit(void) { return cpm_exec("bash lib/shell/commit.sh"); }

/* --- issue: local-first issue tracking --- */
int cmd_issue(int argc, char* argv[]) {
  char cmd[1024] = "bash lib/shell/issue.sh";
  size_t pos = strlen(cmd);
  for (int i = 0; i < argc; i++) {
    int n = snprintf(cmd + pos, sizeof(cmd) - pos, " '%.*s'", (int)(sizeof(cmd) - pos - 4), argv[i]);
    if (n < 0 || pos + (size_t)n >= sizeof(cmd)) break;
    pos += (size_t)n;
  }
  return cpm_exec(cmd);
}
/* --- todo: show TODO/FIXME items from scraper output ---
 *
 * Reads ~/.local/share/cpm/todo-items.jsonl and displays
 * all TODO/FIXME items with ticket references.
 */
int cmd_todo(int argc, char* argv[]) {
  (void)argc;
  (void)argv;

  const char* home = getenv("HOME");
  if (!home) home = ".";
  char path[512];
  snprintf(path, sizeof(path), "%s/.local/share/cpm/todo-items.jsonl", home);

  FILE* f = fopen(path, "r");
  if (!f) {
    ui_error("No TODO items. Run 'cpm check' first to scrape TODO/FIXME comments.");
    return 1;
  }

  printf("TODO/FIXME Items\n");
  printf("================\n\n");

  char line[1024];
  int count = 0;
  int todos = 0;
  int fixes = 0;

  while (fgets(line, sizeof(line), f)) {
    /* Parse JSONL: {"file":"...","line":N,"type":"TODO","ticket":"cpm-42","text":"..."} */
    char file[256] = "", ticket[64] = "", type[16] = "", text[512] = "";
    sscanf(strstr(line, "\"file\":\"") ? strstr(line, "\"file\":\"") + 8 : "", "%255[^\"]", file);
    sscanf(strstr(line, "\"ticket\":\"") ? strstr(line, "\"ticket\":\"") + 10 : "", "%63[^\"]", ticket);
    sscanf(strstr(line, "\"type\":\"") ? strstr(line, "\"type\":\"") + 8 : "", "%15[^\"]", type);
    sscanf(strstr(line, "\"text\":\"") ? strstr(line, "\"text\":\"") + 8 : "", "%511[^\"]", text);

    if (ticket[0]) {
      printf("[%s] %s\n", ticket, type);
      printf("  File: %s\n", file);
      printf("  Text: %s\n\n", text);
      count++;
      if (strcmp(type, "TODO") == 0)
        todos++;
      else
        fixes++;
    }
  }
  fclose(f);

  printf("---\n%d items (%d TODO, %d FIXME)\n", count, todos, fixes);
  return 0;
}

/* --- xref: validate all cross-references ---
 *
 * Runs the xref-validate check and reports broken links.
 */
int cmd_xref(int argc, char* argv[]) {
  (void)argc;
  (void)argv;

  char cmd[512];
  char cwd_buf[512] = ".";
  if (getcwd(cwd_buf, sizeof(cwd_buf)) == nullptr) {
    strncpy(cwd_buf, ".", sizeof(cwd_buf) - 1);
  }
  snprintf(cmd, sizeof(cmd), "bash %s/checks/universal/quality/check-xref-validate.sh . 2>&1", cwd_buf);
  return cpm_exec(cmd);
}

/* --- score: calculate 0-100 maturity score + badge --- */
int cmd_score(void) {
  /* Run scan on current directory silently */
  Repo repo;
  repo.path = ".";
  char cwd[512];
  if (getcwd(cwd, sizeof(cwd))) {
    const char* base = strrchr(cwd, '/');
    repo.name = base ? base + 1 : cwd;
  } else {
    repo.name = "project";
  }

  /* Detect languages */
  if (has_file(".", "package.json")) repo.languages.push_back("typescript");
  if (has_file(".", "Cargo.toml")) repo.languages.push_back("rust");
  if (has_file(".", "go.mod")) repo.languages.push_back("go");
  if (has_file(".", "CMakeLists.txt") || has_file(".", "Makefile")) repo.languages.push_back("cpp");
  if (has_file(".", "pyproject.toml") || has_file(".", "setup.py")) repo.languages.push_back("python");
  if (has_file(".", "composer.json")) repo.languages.push_back("php");

  ScanOptions opts;
  run_repo_checks(repo, opts);

  /* Score formula: start at 100, deduct per finding */
  int score = 100;
  score -= repo.findings_errors * 10;  /* errors cost 10 points each */
  score -= repo.findings_warnings * 3; /* warnings cost 3 points each */
  if (score < 0) score = 0;

  /* Determine color for badge */
  const char* color = "red";
  if (score >= 90)
    color = "brightgreen";
  else if (score >= 80)
    color = "green";
  else if (score >= 70)
    color = "yellowgreen";
  else if (score >= 60)
    color = "yellow";
  else if (score >= 40)
    color = "orange";

  /* Determine level */
  int level = 0;
  if (score >= 95)
    level = 5;
  else if (score >= 85)
    level = 4;
  else if (score >= 70)
    level = 3;
  else if (score >= 50)
    level = 2;
  else if (score >= 30)
    level = 1;

  const char* level_names[] = {"initial", "managed", "defined", "measured", "optimized", "excellent"};

  /* Output */
  const CpmTheme* t = ui_theme();
  printf("\n");
  printf("  %s%s%s — maturity score\n\n", t->info, repo.name.c_str(), t->reset);
  printf("  Score: %s%d/100%s (%s)\n", score >= 70 ? t->success : score >= 40 ? t->warning : t->error, score, t->reset, level_names[level]);
  printf("  Level: %d (%s)\n", level, level_names[level]);
  printf("  Errors: %d | Warnings: %d\n\n", repo.findings_errors, repo.findings_warnings);

  /* Badge markdown */
  printf("  Badge:\n");
  printf("  ![cpm score](https://img.shields.io/badge/cpm%%20score-%d%%25-%s)\n", score, color);
  printf("  ![maturity](https://img.shields.io/badge/maturity-level%%20%d%%20%s-%s)\n\n", level, level_names[level], color);

  /* Markdown snippet for README */
  printf("  Add to README.md:\n");
  printf("  ```\n");
  printf("  ![cpm score](https://img.shields.io/badge/cpm%%20score-%d%%25-%s)\n", score, color);
  printf("  ```\n\n");

  /* Save score for trend tracking */
  platform::make_dir(".cpm");
  FILE* trend = fopen(".cpm/scores.jsonl", "a");
  if (trend) {
    time_t now = time(nullptr);
    struct tm t_buf;
    localtime_r(&now, &t_buf);
    struct tm* t = &t_buf;
    fprintf(trend, "{\"date\":\"%04d-%02d-%02d\",\"score\":%d,\"level\":%d,\"errors\":%d,\"warnings\":%d}\n", t->tm_year + 1900,
            t->tm_mon + 1, t->tm_mday, score, level, repo.findings_errors, repo.findings_warnings);
    fclose(trend);
  }

  /* Show trend if history exists */
  FILE* hist = fopen(".cpm/scores.jsonl", "r");
  if (hist) {
    char line[256];
    int count = 0;
    int first_score = -1;
    while (fgets(line, sizeof(line), hist)) {
      int s = 0;
      char* sp = strstr(line, "\"score\":");
      if (sp) s = atoi(sp + 8);
      if (first_score < 0) first_score = s;
      count++;
    }
    fclose(hist);
    if (count > 1) {
      int delta = score - first_score;
      printf("  Trend: %d measurements", count);
      if (delta > 0)
        printf(" (+%d since first)\n", delta);
      else if (delta < 0)
        printf(" (%d since first)\n", delta);
      else
        printf(" (stable)\n");
      printf("\n");
    }
  }

  return (repo.findings_errors > 0) ? 1 : 0;
}
