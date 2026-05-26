/**
 * @file version.h
 * @brief Semantic version comparison utility.
 */
#ifndef CPM_VERSION_H
#define CPM_VERSION_H

#include <stdio.h>

/** Compare version strings: returns -1 (older), 0 (match), 1 (newer) */
inline int version_cmp(const char* installed, const char* pinned) {
  int ia = 0, ib = 0, ic = 0, pa = 0, pb = 0, pc = 0;
  sscanf(installed, "%d.%d.%d", &ia, &ib, &ic);
  sscanf(pinned, "%d.%d.%d", &pa, &pb, &pc);
  if (ia != pa) return ia > pa ? 1 : -1;
  if (ib != pb) return ib > pb ? 1 : -1;
  if (ic != pc) return ic > pc ? 1 : -1;
  return 0;
}

#endif
