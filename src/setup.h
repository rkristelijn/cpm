/* setup.h — Tool installation for cpm */
#ifndef CPM_SETUP_H
#define CPM_SETUP_H

#include "toml.h"

/* Install all tools from cpm.toml. Returns 0 on success. */
int cpm_setup(CpmConfig *cfg);

/* Print tool versions */
void cpm_versions(CpmConfig *cfg);

#endif
