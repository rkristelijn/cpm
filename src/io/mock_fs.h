/**
// @see ADR-129
 * @file mock_fs.h
 * @brief Mock filesystem for unit testing checks without real files.
 */
#ifndef CPM_IO_MOCK_FS_H
#define CPM_IO_MOCK_FS_H

#include <map>
#include <regex>

#include "filesystem.h"

struct MockFileSystem : FileSystem {
  std::map<std::string, std::string> files;

  void add_file(const std::string& path, const std::string& content) { files[path] = content; }

  bool exists(const std::string& path) override { return files.count(path) > 0; }

  std::string read(const std::string& path) override {
    auto it = files.find(path);
    return it != files.end() ? it->second : "";
  }

  std::vector<std::string> find_files(const std::string& dir, const std::string& pattern) override {
    std::vector<std::string> results;
    std::regex re(pattern);
    for (auto& [path, _] : files) {
      if (path.find(dir) == 0 && std::regex_search(path, re)) results.push_back(path);
    }
    return results;
  }
};

#endif
