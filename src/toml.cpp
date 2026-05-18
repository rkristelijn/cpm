/* toml.c — Minimal TOML parser for cpm.toml
 *
 * Supports: [sections], key = "value", key = true/false, key = 123
 * Supports dotted keys: checks.complexity.threshold = 10
 * Ignores comments (#) and blank lines.
 */
#include "toml.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void trim(char* s) {
  char* end;
  while (isspace((unsigned char)*s)) memmove(s, s + 1, strlen(s));
  end = s + strlen(s) - 1;
  while (end > s && isspace((unsigned char)*end)) *end-- = '\0';
}

static void strip_quotes(char* s) {
  size_t len = strlen(s);
  if (len >= 2 && s[0] == '"' && s[len - 1] == '"') {
    memmove(s, s + 1, len - 2);
    s[len - 2] = '\0';
  }
}

void cpm_toml_defaults(CpmConfig* cfg) {
  memset(cfg, 0, sizeof(*cfg));
  strcpy(cfg->lang, "c");
  strcpy(cfg->build, "make");
  strcpy(cfg->version, "0.0.0");
  strcpy(cfg->config_dir, ".config");
  cfg->cflags[0] = '\0';
  cfg->ldflags[0] = '\0';
  cfg->config_count = 0;
  cfg->binary_count = 0;
  cfg->hook_pre_commit = true;
  cfg->hook_pre_push = true;
  cfg->hook_commit_msg = false;
  cfg->timeout = 30;
  /* Auto-detect lang from files in current directory */
  cpm_detect_lang(cfg);
}

void cpm_detect_lang(CpmConfig* cfg) {
  FILE* p = popen(
      "find . -not -path './.git/*' -not -path './node_modules/*' "
      "-not -path './vendor/*' -not -path './.terraform/*' "
      "-type f 2>/dev/null | sed 's/.*\\.//' | sort | uniq -c | sort -rn | head -10",
      "r");
  if (!p) return;
  char buf[128];
  while (fgets(buf, sizeof(buf), p)) {
    char ext[32] = {};
    sscanf(buf, " %*d %31s", ext);
    int found = 1;
    if (strcmp(ext, "ts") == 0 || strcmp(ext, "tsx") == 0 ||
        strcmp(ext, "js") == 0 || strcmp(ext, "jsx") == 0)
      strcpy(cfg->lang, "typescript");
    else if (strcmp(ext, "py") == 0)
      strcpy(cfg->lang, "python");
    else if (strcmp(ext, "java") == 0)
      strcpy(cfg->lang, "java");
    else if (strcmp(ext, "tf") == 0 || strcmp(ext, "hcl") == 0)
      strcpy(cfg->lang, "terraform");
    else if (strcmp(ext, "rs") == 0)
      strcpy(cfg->lang, "rust");
    else if (strcmp(ext, "cpp") == 0 || strcmp(ext, "hpp") == 0 ||
             strcmp(ext, "cc") == 0)
      strcpy(cfg->lang, "cpp");
    else if (strcmp(ext, "php") == 0)
      strcpy(cfg->lang, "php");
    else if (strcmp(ext, "go") == 0)
      strcpy(cfg->lang, "go");
    else if (strcmp(ext, "rb") == 0)
      strcpy(cfg->lang, "ruby");
    else if (strcmp(ext, "cs") == 0)
      strcpy(cfg->lang, "csharp");
    else
      found = 0;
    if (found) break; /* First recognized lang wins */
  }
  pclose(p);
  /* Auto-detect build system */
  FILE* f;
  if ((f = fopen("package.json", "r"))) {
    strcpy(cfg->build, "npm");
    fclose(f);
  } else if ((f = fopen("CMakeLists.txt", "r"))) {
    strcpy(cfg->build, "cmake");
    fclose(f);
  } else if ((f = fopen("pom.xml", "r"))) {
    strcpy(cfg->build, "maven");
    fclose(f);
  } else if ((f = fopen("build.gradle", "r"))) {
    strcpy(cfg->build, "gradle");
    fclose(f);
  } else if ((f = fopen("Cargo.toml", "r"))) {
    strcpy(cfg->build, "cargo");
    fclose(f);
  }
}

/* Add or find a check entry */
static CpmCheck* ensure_check(CpmConfig* cfg, const char* name) {
  CpmCheck* c = cpm_check_find(cfg, name);
  if (c) return c;
  if (cfg->check_count >= CPM_MAX_CHECKS) return NULL;
  c = &cfg->checks[cfg->check_count++];
  snprintf(c->name, CPM_MAX_KEYLEN, "%s", name);
  c->enabled = true;
  c->warn_only = false;
  c->threshold = -1;
  c->command[0] = '\0';
  return c;
}

int cpm_toml_parse(const char* path, CpmConfig* cfg) {
  FILE* f = fopen(path, "r");
  if (!f) return -1;

  cpm_toml_defaults(cfg);

  char line[512];
  char section[64] = "";

  while (fgets(line, sizeof(line), f)) {
    trim(line);
    if (line[0] == '\0' || line[0] == '#') continue;

    /* [section] */
    if (line[0] == '[') {
      char* end = strchr(line, ']');
      if (!end) continue;
      *end = '\0';
      snprintf(section, sizeof(section), "%s", line + 1);
      continue;
    }

    /* key = value — find first '=' not inside quotes */
    char* eq = NULL;
    bool in_quotes = false;
    for (char* p = line; *p; p++) {
      if (*p == '"') in_quotes = !in_quotes;
      if (*p == '=' && !in_quotes) {
        eq = p;
        break;
      }
    }
    if (!eq) continue;
    *eq = '\0';
    char key[128], val[256];
    snprintf(key, sizeof(key), "%s", line);
    snprintf(val, sizeof(val), "%s", eq + 1);
    trim(key);
    trim(val);
    strip_quotes(val);

    if (strcmp(section, "project") == 0) {
      if (strcmp(key, "name") == 0)
        snprintf(cfg->name, CPM_MAX_VALLEN, "%s", val);
      else if (strcmp(key, "version") == 0)
        snprintf(cfg->version, sizeof(cfg->version), "%s", val);
      else if (strcmp(key, "lang") == 0)
        snprintf(cfg->lang, sizeof(cfg->lang), "%s", val);
      else if (strcmp(key, "build") == 0)
        snprintf(cfg->build, sizeof(cfg->build), "%s", val);
      else if (strcmp(key, "config-dir") == 0)
        snprintf(cfg->config_dir, sizeof(cfg->config_dir), "%s", val);
      else if (strcmp(key, "cflags") == 0)
        snprintf(cfg->cflags, sizeof(cfg->cflags), "%s", val);
      else if (strcmp(key, "ldflags") == 0)
        snprintf(cfg->ldflags, sizeof(cfg->ldflags), "%s", val);
    } else if (strcmp(section, "tools") == 0) {
      if (cfg->tool_count < CPM_MAX_TOOLS) {
        CpmTool* t = &cfg->tools[cfg->tool_count++];
        snprintf(t->name, CPM_MAX_KEYLEN, "%s", key);
        snprintf(t->version, CPM_MAX_VALLEN, "%s", val);
      }
    } else if (strcmp(section, "hooks") == 0) {
      bool bval = strcmp(val, "true") == 0;
      if (strcmp(key, "pre-commit") == 0)
        cfg->hook_pre_commit = bval;
      else if (strcmp(key, "pre-push") == 0)
        cfg->hook_pre_push = bval;
      else if (strcmp(key, "commit-msg") == 0)
        cfg->hook_commit_msg = bval;
    } else if (strcmp(section, "runner") == 0) {
      if (strcmp(key, "timeout") == 0) cfg->timeout = atoi(val);
    } else if (strcmp(section, "configs") == 0) {
      if (cfg->config_count < CPM_MAX_CONFIGS) {
        auto* e = &cfg->configs[cfg->config_count++];
        snprintf(e->key, CPM_MAX_KEYLEN, "%s", key);
        snprintf(e->path, CPM_MAX_VALLEN, "%s", val);
      }
    } else if (strcmp(section, "binaries") == 0) {
      if (cfg->binary_count < CPM_MAX_BINARIES) {
        auto* b = &cfg->binaries[cfg->binary_count++];
        snprintf(b->name, CPM_MAX_KEYLEN, "%s", key);
        snprintf(b->source, CPM_MAX_VALLEN, "%s", val);
      }
    } else if (strcmp(section, "checks") == 0) {
      /* Simple: check-name = true/false */
      if (strcmp(val, "true") == 0 || strcmp(val, "false") == 0) {
        CpmCheck* c = ensure_check(cfg, key);
        if (c) c->enabled = strcmp(val, "true") == 0;
      }
    } else if (strncmp(section, "checks.", 7) == 0) {
      /* Dotted section: [checks.complexity] */
      const char* check_name = section + 7;
      CpmCheck* c = ensure_check(cfg, check_name);
      if (c) {
        if (strcmp(key, "enabled") == 0)
          c->enabled = strcmp(val, "true") == 0;
        else if (strcmp(key, "warn-only") == 0)
          c->warn_only = strcmp(val, "true") == 0;
        else if (strcmp(key, "threshold") == 0)
          c->threshold = atoi(val);
        else if (strcmp(key, "command") == 0)
          snprintf(c->command, CPM_MAX_VALLEN, "%s", val);
      }
    }
  }

  fclose(f);
  return 0;
}

CpmTool* cpm_tool_find(CpmConfig* cfg, const char* name) {
  for (int i = 0; i < cfg->tool_count; i++)
    if (strcmp(cfg->tools[i].name, name) == 0) return &cfg->tools[i];
  return NULL;
}

CpmCheck* cpm_check_find(CpmConfig* cfg, const char* name) {
  for (int i = 0; i < cfg->check_count; i++)
    if (strcmp(cfg->checks[i].name, name) == 0) return &cfg->checks[i];
  return NULL;
}

/* Default config paths (config_dir/filename) */
struct CfgDefault {
  const char* key;
  const char* file;
};
static const CfgDefault CFG_DEFAULTS[] = {{"clang-format", ".clang-format"}, {"clang-tidy", ".clang-tidy"}, {"yamllint", "yamllint.yml"},
                                          {"rumdl", "rumdl.toml"},           {"doxyfile", "Doxyfile"},      {NULL, NULL}};

const char* cpm_config_path(CpmConfig* cfg, const char* key) {
  /* Check explicit [configs] entries first */
  for (int i = 0; i < cfg->config_count; i++)
    if (strcmp(cfg->configs[i].key, key) == 0) return cfg->configs[i].path;

  /* Fall back to config_dir/default_filename */
  for (int i = 0; CFG_DEFAULTS[i].key; i++) {
    if (strcmp(CFG_DEFAULTS[i].key, key) == 0) {
      /* Build path into a static buffer per key (max 5 keys) */
      static char bufs[5][256];
      snprintf(bufs[i], sizeof(bufs[i]), "%s/%s", cfg->config_dir, CFG_DEFAULTS[i].file);
      return bufs[i];
    }
  }
  return NULL;
}
