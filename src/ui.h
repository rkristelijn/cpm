/**
 * @file ui.h
 * @brief Centralized terminal output with theme support.
 *
 * All user-facing output goes through this module. Ensures:
 * - Consistent symbols and colors across all commands
 * - NO_COLOR support (https://no-color.org/)
 * - Role-based styling (success/error/warning/info), never hardcoded ANSI
 * - Symbols always present (never color-only status indication)
 *
 * @see lib/shell/ui.sh for the bash equivalent
 */
#ifndef CPM_UI_H
#define CPM_UI_H

/** @brief Theme roles — maps semantic meaning to ANSI colors. */
typedef struct {
  const char *success;  /**< green: passed checks, created files */
  const char *error;    /**< red: failures */
  const char *warning;  /**< yellow: warnings, skipped */
  const char *info;     /**< bold: headers, tier labels */
  const char *reset;    /**< reset all attributes */
} CpmTheme;

/** @brief Get active theme (respects NO_COLOR env var). */
const CpmTheme *ui_theme(void);

/** @name Check result output */
/**@{*/
void ui_success(const char *name, double secs);
void ui_fail(const char *name);
void ui_skip(const char *name);
void ui_warn(const char *name);
/**@}*/

/** @name Section headers */
/**@{*/
void ui_header(const char *label, int count);
void ui_summary(int pass, int fail, int warn, int skip, double secs);
void ui_tier(const char *label);
/**@}*/

/** @name Messages */
/**@{*/
void ui_info(const char *msg);
void ui_created(const char *path);
void ui_error(const char *msg);
/**@}*/

#endif
