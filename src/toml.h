/* toml.h — Minimal TOML parser for cpm.toml */
#ifndef CPM_TOML_H
#define CPM_TOML_H

#include <stdbool.h>

#define CPM_MAX_TOOLS   32
#define CPM_MAX_CHECKS  32
#define CPM_MAX_KEYLEN  64
#define CPM_MAX_VALLEN  128

typedef struct {
    char name[CPM_MAX_KEYLEN];
    char version[CPM_MAX_VALLEN];
} CpmTool;

typedef struct {
    char name[CPM_MAX_KEYLEN];
    bool enabled;
    bool warn_only;
    int  threshold;       /* -1 = not set */
    char command[CPM_MAX_VALLEN]; /* override command */
} CpmCheck;

typedef struct {
    /* [project] */
    char name[CPM_MAX_VALLEN];
    char version[32];
    char lang[16];        /* "c" or "cpp" */
    char build[16];       /* "make" or "cmake" */
    char config_dir[128]; /* default dir for init, not used at runtime */
    char cflags[256];    /* extra compiler flags, e.g. "-I vendor" */
    char ldflags[256];   /* extra linker flags, e.g. "-framework CoreAudio" */

    /* [configs] — per-tool config file paths */
    #define CPM_MAX_CONFIGS 16
    struct { char key[CPM_MAX_KEYLEN]; char path[CPM_MAX_VALLEN]; } configs[CPM_MAX_CONFIGS];
    int config_count;

    /* [tools] */
    CpmTool tools[CPM_MAX_TOOLS];
    int     tool_count;

    /* [checks] */
    CpmCheck checks[CPM_MAX_CHECKS];
    int      check_count;

    /* [binaries] — extra binaries beyond the main one */
    #define CPM_MAX_BINARIES 8
    struct { char name[CPM_MAX_KEYLEN]; char source[CPM_MAX_VALLEN]; } binaries[CPM_MAX_BINARIES];
    int binary_count;

    /* [hooks] */
    bool hook_pre_commit;
    bool hook_pre_push;
    bool hook_commit_msg;
} CpmConfig;

/* Parse cpm.toml, returns 0 on success */
int cpm_toml_parse(const char *path, CpmConfig *cfg);

/* Find a tool by name, returns NULL if not found */
CpmTool *cpm_tool_find(CpmConfig *cfg, const char *name);

/* Find a check by name, returns NULL if not found */
CpmCheck *cpm_check_find(CpmConfig *cfg, const char *name);

/* Get config file path by key (e.g. "clang-format"), returns default if not set */
const char *cpm_config_path(CpmConfig *cfg, const char *key);

#endif
