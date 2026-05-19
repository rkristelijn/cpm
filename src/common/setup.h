/**
 * @file setup.h
 * @brief Tool installation — installs quality tools from cpm.toml [tools].
 *
 * Detects platform (macOS/Linux) and uses brew/apt to install pinned versions.
 */
#ifndef CPM_SETUP_H
#define CPM_SETUP_H

#include "toml.h"

/**
 * @brief Install all tools listed in cpm.toml [tools] section.
 * @return 0 on success.
 */
int cpm_setup(CpmConfig* cfg);

/**
 * @brief Print installed versions of all configured tools.
 */
void cpm_versions(CpmConfig* cfg);

#endif
