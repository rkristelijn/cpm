/* toml.c — Minimal TOML parser for cpm.toml
// @see ADR-129
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

#include "compat.h"
#include "constants.h"

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
  snprintf(cfg->lang, sizeof(cfg->lang), "c");
  snprintf(cfg->build, sizeof(cfg->build), "make");
  snprintf(cfg->version, sizeof(cfg->version), "0.0.0");
  snprintf(cfg->config_dir, sizeof(cfg->config_dir), ".config");
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
  /* Extension-to-language mapping */
  static const struct {
    const char* exts[4]; /* up to 4 extensions per language */
    const char* lang;
  } lang_map[] = {
      {{"ts", "tsx", "js", "jsx"}, "typescript"},
      {{"py", nullptr}, "python"},
      {{"java", nullptr}, "java"},
      {{"tf", "hcl", nullptr}, "terraform"},
      {{"rs", nullptr}, "rust"},
      {{"cpp", "hpp", "cc", nullptr}, "cpp"},
      {{"php", nullptr}, "php"},
      {{"go", nullptr}, "go"},
      {{"rb", nullptr}, "ruby"},
      {{"cs", nullptr}, "csharp"},
  };

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
    bool found = false;
    for (auto& entry : lang_map) {
      for (int i = 0; i < 4 && entry.exts[i]; i++) {
        if (strcmp(ext, entry.exts[i]) == 0) {
          snprintf(cfg->lang, sizeof(cfg->lang), "%s", entry.lang);
          found = true;
          break;
        }
      }
      if (found) break;
    }
    if (found) break;
  }
  pclose(p);
  /* Auto-detect build system */
  static const struct {
    const char* file;
    const char* build;
  } build_map[] = {
      {"package.json", "npm"}, {"CMakeLists.txt", "cmake"}, {"pom.xml", "maven"}, {"build.gradle", "gradle"}, {"Cargo.toml", "cargo"},
  };
  for (auto& entry : build_map) {
    FILE* f = fopen(entry.file, "r");
    if (f) {
      snprintf(cfg->build, sizeof(cfg->build), "%s", entry.build);
      fclose(f);
      break;
    }
  }
}

/* Add or find a check entry */
static CpmCheck* ensure_check(CpmConfig* cfg, const char* name) {
  CpmCheck* c = cpm_check_find(cfg, name);
  if (c) return c;
  if (cfg->check_count >= CPM_MAX_CHECKS) return nullptr;
  c = &cfg->checks[cfg->check_count++];
  snprintf(c->name, CPM_MAX_KEYLEN, "%s", name);
  c->enabled = true;
  c->warn_only = false;
  c->threshold = -1;
  c->command[0] = '\0';
  return c;
}

/* Intentional truncation: TOML keys/sections are short; snprintf clips gracefully. */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat-truncation"
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
    char* eq = nullptr;
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
#pragma GCC diagnostic pop

CpmTool* cpm_tool_find(CpmConfig* cfg, const char* name) {
  for (int i = 0; i < cfg->tool_count; i++)
    if (strcmp(cfg->tools[i].name, name) == 0) return &cfg->tools[i];
  return nullptr;
}

CpmCheck* cpm_check_find(CpmConfig* cfg, const char* name) {
  for (int i = 0; i < cfg->check_count; i++)
    if (strcmp(cfg->checks[i].name, name) == 0) return &cfg->checks[i];
  return nullptr;
}

/* Default config paths (config_dir/filename) */
struct CfgDefault {
  const char* key;
  const char* file;
};
static const CfgDefault CFG_DEFAULTS[] = {{"clang-format", ".clang-format"}, {"clang-tidy", ".clang-tidy"}, {"yamllint", "yamllint.yml"},
                                          {"rumdl", "rumdl.toml"},           {"doxyfile", "Doxyfile"},      {nullptr, nullptr}};

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
  return nullptr;
}
