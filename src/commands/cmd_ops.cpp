/**
 * @file cmd_ops.cpp
 * @brief Operational commands: hooks, config, findings, reporting, git.
 * @see ADR-129
 */
#include "commands.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <time.h>
#include <unistd.h>
#include "runner.h"
#include "toml.h"
#include "ui.h"

#include "setup.h"
#include "io/drawio.h"

#define CPM_FILE "cpm.toml"
int cmd_hook(CpmConfig* cfg) {
  printf("Installing git hooks...\n");
  if (cfg->hook_pre_commit)
    cpm_exec("mkdir -p .git/hooks && printf '#!/bin/sh\\ncpm check --fast\\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit");
  if (cfg->hook_pre_push)
    cpm_exec(
        "mkdir -p .git/hooks && printf '#!/bin/sh\\n"
        "BRANCH=$(git rev-parse --abbrev-ref HEAD)\\n"
        "if [ \"$BRANCH\" = \"main\" ] || [ \"$BRANCH\" = \"master\" ]; then\\n"
        "  echo \"  ✗ Direct push to $BRANCH blocked. Use a feature branch.\"\\n"
        "  exit 1\\n"
        "fi\\n"
        "cpm check\\n' > .git/hooks/pre-push && chmod +x .git/hooks/pre-push");
  if (cfg->hook_commit_msg)
    cpm_exec(
        "mkdir -p .git/hooks && printf '#!/bin/sh\\n# conventional commit check\\n' > .git/hooks/commit-msg && chmod +x "
        ".git/hooks/commit-msg");
  printf("Done.\n");
  return 0;
}

int cmd_unhook(void) {
  printf("Removing git hooks...\n");
  cpm_exec("rm -f .git/hooks/pre-commit .git/hooks/pre-push .git/hooks/commit-msg");
  printf("Done.\n");
  return 0;
}

/* --- bump: semantic version increment ---
 *
 * Reads current version from cpm.toml, increments the specified part,
 * writes back using sed (portable, no TOML library needed for write).
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

  /* Use sed to update in-place (works on macOS and Linux) */
  char cmd[512];
  snprintf(cmd, sizeof(cmd), "sed -i '' 's/^version = \".*\"/version = \"%s\"/' %s", newver, CPM_FILE);
  cpm_exec(cmd);

  /* Update CPM_VERSION in commands.h */
  snprintf(cmd, sizeof(cmd), "sed -i '' 's/#define CPM_VERSION \".*\"/#define CPM_VERSION \"%s\"/' src/commands.h", newver);
  cpm_exec(cmd);

  printf("%s → %s\n", cfg->version, newver);
  return 0;
}

/* --- audit: compare installed tool versions against cpm.toml pins --- */
int cmd_audit(CpmConfig* cfg) {
  printf("cpm audit — checking tool versions\n\n");
  cpm_versions(cfg);
  printf("\nNote: version mismatch detection coming soon.\n");
  return 0;
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
  /* Use sed for in-place update (same approach as bump) */
  char cmd[512];
  snprintf(cmd, sizeof(cmd), "sed -i '' 's/^%s = .*/%s = %s/' %s", key, key, val, CPM_FILE);
  cpm_exec(cmd);
  printf("%s = %s\n", key, val);
  return 0;
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
  const char* files[] = {"%s/.local/share/cpm/scan-findings.jsonl", "%s/.local/share/cpm/check-findings.jsonl", NULL};
  char path[512];
  FILE* f = NULL;

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
  const char* repo_filter = NULL;
  const char* severity_filter = NULL;
  bool junit = false;

  for (int i = 0; i < argc; i++) {
    if (strcmp(argv[i], "--severity") == 0 && i + 1 < argc) {
      severity_filter = argv[++i];
    } else if (strcmp(argv[i], "--junit") == 0) {
      junit = true;
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

    if (junit) {
      /* Extract fields for JUnit */
      char repo[128] = "", check[128] = "", sev[32] = "", msg[512] = "";
      sscanf(strstr(line, "\"repo\":\"") ? strstr(line, "\"repo\":\"") + 8 : "", "%127[^\"]", repo);
      sscanf(strstr(line, "\"check\":\"") ? strstr(line, "\"check\":\"") + 9 : "", "%127[^\"]", check);
      sscanf(strstr(line, "\"severity\":\"") ? strstr(line, "\"severity\":\"") + 12 : "", "%31[^\"]", sev);
      sscanf(strstr(line, "\"message\":\"") ? strstr(line, "\"message\":\"") + 11 : "", "%511[^\"]", msg);
      if (strcmp(sev, "error") == 0)
        printf("  <testcase name=\"%s/%s\"><failure message=\"%s\"/></testcase>\n", repo, check, msg);
      else
        printf("  <testcase name=\"%s/%s\"><!-- %s: %s --></testcase>\n", repo, check, sev, msg);
    } else {
      /* Pretty-print: colored severity + repo + message */
      char repo[128] = "", check[128] = "", sev[32] = "", msg[512] = "";
      sscanf(strstr(line, "\"repo\":\"") ? strstr(line, "\"repo\":\"") + 8 : "", "%127[^\"]", repo);
      sscanf(strstr(line, "\"check\":\"") ? strstr(line, "\"check\":\"") + 9 : "", "%127[^\"]", check);
      sscanf(strstr(line, "\"severity\":\"") ? strstr(line, "\"severity\":\"") + 12 : "", "%31[^\"]", sev);
      sscanf(strstr(line, "\"message\":\"") ? strstr(line, "\"message\":\"") + 11 : "", "%511[^\"]", msg);

      const char* color = strcmp(sev, "error") == 0 ? t->error : t->warning;
      printf("  %s%-7s%s %-20s %-15s %s\n", color, sev, t->reset, repo, check, msg);
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

      if (junit) {
        char repo[128] = "", check[128] = "", sev[32] = "", msg[512] = "";
        sscanf(strstr(line, "\"check\":\"") ? strstr(line, "\"check\":\"") + 9 : "", "%127[^\"]", check);
        sscanf(strstr(line, "\"severity\":\"") ? strstr(line, "\"severity\":\"") + 12 : "", "%31[^\"]", sev);
        sscanf(strstr(line, "\"message\":\"") ? strstr(line, "\"message\":\"") + 11 : "", "%511[^\"]", msg);
        sscanf(strstr(line, "\"rule\":\"") ? strstr(line, "\"rule\":\"") + 8 : "", "%127[^\"]", repo);
        printf("  <testcase name=\"check/%s\"><failure message=\"%s\"/></testcase>\n", check, msg);
      } else {
        char check[128] = "", sev[32] = "", msg[512] = "";
        sscanf(strstr(line, "\"check\":\"") ? strstr(line, "\"check\":\"") + 9 : "", "%127[^\"]", check);
        sscanf(strstr(line, "\"severity\":\"") ? strstr(line, "\"severity\":\"") + 12 : "", "%31[^\"]", sev);
        sscanf(strstr(line, "\"message\":\"") ? strstr(line, "\"message\":\"") + 11 : "", "%511[^\"]", msg);
        const char* color = strcmp(sev, "error") == 0 ? t->error : t->warning;
        printf("  %s%-7s%s %-20s %-15s %s\n", color, sev, t->reset, ".", check, msg);
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
      strncpy(checks[check_count], check, 127);
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
      strncpy(repos[repo_count], repo, 127);
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
        strcpy(t, checks[i]);
        strcpy(checks[i], checks[j]);
        strcpy(checks[j], t);
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
        strcpy(t, repos[i]);
        strcpy(repos[i], repos[j]);
        strcpy(repos[j], t);
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
  for (int i = 0; i < argc; i++) {
    strcat(cmd, " ");
    strcat(cmd, "'");
    strncat(cmd, argv[i], sizeof(cmd) - strlen(cmd) - 3);
    strcat(cmd, "'");
  }
  return cpm_exec(cmd);
}

/* --- drawio: read and describe drawio diagram files ---
 *
 * Usage:
 *   cpm drawio <file.drawio>           — describe the diagram
 *   cpm drawio <file.drawio> --mermaid — output as mermaid flowchart
 *   cpm drawio <file.drawio> --json    — output as JSON
 */
int cmd_drawio(int argc, char* argv[]) {
  (void)argc;

  const char* path = NULL;
  bool as_mermaid = false;
  bool as_json = false;

  for (int i = 0; i < argc; i++) {
    if (strcmp(argv[i], "--mermaid") == 0)
      as_mermaid = true;
    else if (strcmp(argv[i], "--json") == 0)
      as_json = true;
    else if (argv[i][0] != '-')
      path = argv[i];
  }

  if (!path) {
    fprintf(stderr, "Usage: cpm drawio <file.drawio> [--mermaid|--json]\n");
    return 1;
  }

  if (!drawio_detect(path)) {
    fprintf(stderr, "Error: %s does not appear to be a drawio diagram\n", path);
    return 1;
  }

  DrawioDiagram diagram = drawio_read(path);
  if (diagram.node_count == 0 && diagram.edge_count == 0) {
    fprintf(stderr, "Error: failed to parse %s\n", path);
    return 1;
  }

  if (as_json) {
    printf("%s", drawio_to_json(diagram).c_str());
  } else if (as_mermaid) {
    printf("%s", drawio_to_mermaid(diagram).c_str());
  } else {
    printf("%s", drawio_describe(diagram).c_str());
  }

  return 0;
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
  snprintf(cmd, sizeof(cmd), "bash %s/checks/universal/quality/check-xref-validate.sh . 2>&1", getenv("PWD") ? getenv("PWD") : ".");
  return cpm_exec(cmd);
}