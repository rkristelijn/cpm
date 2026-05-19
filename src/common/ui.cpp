/* ui.cpp — Centralized terminal output with theme support
// @see ADR-129
 *
 * All styling is role-based: success/error/warning/info.
 * NO_COLOR disables all ANSI codes (accessibility compliance).
 * Symbols always present (never color-only status indication).
 */
#include "ui.h"

#include <stdio.h>
#include <stdlib.h>

/* Default theme — green/red/yellow with bold headers */
static const CpmTheme THEME_COLOR = {
    "\033[32m", /* success: green */
    "\033[31m", /* error: red */
    "\033[33m", /* warning: yellow */
    "\033[1m",  /* info: bold */
    "\033[0m"   /* reset */
};

/* NO_COLOR theme — no ANSI codes at all */
static const CpmTheme THEME_NONE = {"", "", "", "", ""};

const CpmTheme* ui_theme(void) { return getenv("NO_COLOR") ? &THEME_NONE : &THEME_COLOR; }

void ui_success(const char* name, double secs) {
  const CpmTheme* t = ui_theme();
  printf("  %s✓%s %-20s %.1fs\n", t->success, t->reset, name, secs);
}

void ui_fail(const char* name) {
  const CpmTheme* t = ui_theme();
  printf("  %s✗%s %-20s FAILED\n", t->error, t->reset, name);
}

void ui_skip(const char* name) {
  const CpmTheme* t = ui_theme();
  printf("  %s⊘%s %-20s skipped\n", t->warning, t->reset, name);
}

void ui_warn(const char* name) {
  const CpmTheme* t = ui_theme();
  printf("  %s⚠%s %-20s warning\n", t->warning, t->reset, name);
}

void ui_header(const char* label, int count) {
  const CpmTheme* t = ui_theme();
  printf("\n%s%s%s (%d checks)\n", t->info, label, t->reset, count);
}

void ui_summary(int pass, int fail, int warn, int skip, double secs) {
  printf("\n  %d passed, %d failed, %d warned, %d skipped (%.1fs)\n", pass, fail, warn, skip, secs);
}

void ui_tier(const char* label) {
  const CpmTheme* t = ui_theme();
  printf("\n%s=== %s ===%s\n", t->info, label, t->reset);
}

void ui_info(const char* msg) { printf("  %s\n", msg); }

void ui_created(const char* path) {
  const CpmTheme* t = ui_theme();
  printf("  %s✓%s Created %s\n", t->success, t->reset, path);
}

void ui_error(const char* msg) {
  const CpmTheme* t = ui_theme();
  fprintf(stderr, "  %s✗%s %s\n", t->error, t->reset, msg);
}
