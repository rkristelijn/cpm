/**
 * @file filesystem.h
 * @brief Mockable file system interface — all file I/O goes through this.
 */
#ifndef CPM_IO_FILESYSTEM_H
#define CPM_IO_FILESYSTEM_H

#include <string>
#include <vector>

struct FileSystem {
  virtual ~FileSystem() = default;
  virtual bool exists(const std::string& path) = 0;
  virtual std::string read(const std::string& path) = 0;
  virtual std::vector<std::string> find_files(const std::string& dir, const std::string& pattern) = 0;
};

/** @brief Real filesystem implementation. */
struct RealFileSystem : FileSystem {
  bool exists(const std::string& path) override;
  std::string read(const std::string& path) override;
  std::vector<std::string> find_files(const std::string& dir, const std::string& pattern) override;
};

#endif
