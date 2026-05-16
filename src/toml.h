/**
 * @file toml.h
 * @brief Minimal TOML parser for cpm.toml configuration files.
 *
 * Parses [project], [tools], [checks], [hooks], [configs], and [binaries]
 * sections. Supports nested check config (e.g. [checks.lint-code] threshold).
 * No external dependencies — hand-rolled parser for zero-dep philosophy.
 */
#ifndef CPM_TOML_H
#define CPM_TOML_H

#include <stdbool.h>

#define CPM_MAX_TOOLS   32
#define CPM_MAX_CHECKS  32
#define CPM_MAX_KEYLEN  64
#define CPM_MAX_VALLEN  128

/** @brief A pinned tool version from [tools] section. */
typedef struct {
    char name[CPM_MAX_KEYLEN];
    char version[CPM_MAX_VALLEN];
} CpmTool;

/** @brief A quality check from [checks] section with optional config. */
typedef struct {
    char name[CPM_MAX_KEYLEN];
    bool enabled;
    bool warn_only;
    int  threshold;       /**< -1 = not set */
    char command[CPM_MAX_VALLEN]; /**< override command from [checks.name] */
} CpmCheck;

/** @brief Complete parsed cpm.toml configuration. */
typedef struct {
    /* [project] */
    char name[CPM_MAX_VALLEN];
    char version[32];
    char lang[16];        /**< "c" or "cpp" */
    char build[16];       /**< "make" or "cmake" */
    char config_dir[128]; /**< config file directory (default ".config") */
    char cflags[256];     /**< extra compiler flags */
    char ldflags[256];    /**< extra linker flags */

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

/**
 * @brief Parse cpm.toml into a CpmConfig struct.
 * @param path Path to the TOML file.
 * @param cfg Output config struct (caller-allocated).
 * @return 0 on success, non-zero on error.
 */
int cpm_toml_parse(const char *path, CpmConfig *cfg);

/**
 * @brief Find a tool by name in the parsed config.
 * @return Pointer to tool, or NULL if not found.
 */
CpmTool *cpm_tool_find(CpmConfig *cfg, const char *name);

/**
 * @brief Find a check by name in the parsed config.
 * @return Pointer to check, or NULL if not found.
 */
CpmCheck *cpm_check_find(CpmConfig *cfg, const char *name);

/**
 * @brief Get config file path by key (e.g. "clang-format").
 * @return Path string, or default if not set.
 */
const char *cpm_config_path(CpmConfig *cfg, const char *key);

#endif
