/**
// @see ADR-129
 * @file filesystem.cpp
 * @brief Real filesystem implementation using POSIX/C++ standard library.
 */
#include "filesystem.h"

#include <dirent.h>
#include <sys/stat.h>

#include <cstdio>
#include <cstring>
#include <regex>

bool RealFileSystem::exists(const std::string& path) {
  struct stat st;
  return stat(path.c_str(), &st) == 0;
}

std::string RealFileSystem::read(const std::string& path) {
  FILE* f = fopen(path.c_str(), "r");
  if (!f) return "";
  std::string content;
  char buf[4096];
  size_t n;
  while ((n = fread(buf, 1, sizeof(buf), f)) > 0) content.append(buf, n);
  fclose(f);
  return content;
}

std::vector<std::string> RealFileSystem::find_files(const std::string& dir, const std::string& pattern) {
  std::vector<std::string> results;
  std::regex re(pattern);
  DIR* d = opendir(dir.c_str());
  if (!d) return results;
  struct dirent* entry;
  while ((entry = readdir(d))) {
    if (entry->d_name[0] == '.') continue;
    std::string full = dir + "/" + entry->d_name;
    struct stat st;
    if (stat(full.c_str(), &st) != 0) continue;
    if (S_ISREG(st.st_mode) && std::regex_search(entry->d_name, re))
      results.push_back(full);
    else if (S_ISDIR(st.st_mode)) {
      auto sub = find_files(full, pattern);
      results.insert(results.end(), sub.begin(), sub.end());
    }
  }
  closedir(d);
  return results;
}
