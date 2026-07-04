/**
 * @file line_scanner.h
 * @brief Reusable line-iteration helper to eliminate boilerplate in checks.
 *
 * Before (repeated in 18+ checks):
 *   auto files = fs.find_files("src", regex);
 *   for (auto& file : files) {
 *     std::string content = fs.read(file);
 *     int line = 0; size_t pos = 0;
 *     while (pos < content.size()) {
 *       size_t eol = content.find('\n', pos);
 *       if (eol == std::string::npos) eol = content.size();
 *       std::string ln = content.substr(pos, eol - pos);
 *       line++;
 *       // ... per-line logic ...
 *
 * After:
 *   scan_lines(fs, "src", "\\.(cpp|h)$", [&](auto& file, int line, auto& ln) {
 *     // ... per-line logic ...
 *   });
 *
 * @see ADR-151 (compression-inspired duplication detection)
 */
#ifndef CPM_LINE_SCANNER_H
#define CPM_LINE_SCANNER_H

#include <functional>
#include <string>

#include "io/filesystem.h"

/**
 * @brief Scan all matching files line-by-line, calling visitor for each line.
 *
 * @param fs         FileSystem (mockable for tests)
 * @param dir        Directory to scan (e.g., "src")
 * @param pattern    Regex for file extensions (e.g., "\\.(cpp|h|ts|js)$")
 * @param visitor    Callback(file, line_number, line_content)
 *
 * Performance notes (from C++ optimization best practices):
 * - Passes content by single read per file, iterates with substr (TODO: string_view in future)
 * - Passes file by const& (no copy)
 * - Reuses content buffer per file (single allocation)
 */
inline void scan_lines(FileSystem& fs, const std::string& dir, const std::string& pattern,
                       std::function<void(const std::string& file, int line, const std::string& ln)> visitor) {
  auto files = fs.find_files(dir, pattern);
  for (const auto& file : files) {
    std::string content = fs.read(file);
    int line = 0;
    size_t pos = 0;
    while (pos < content.size()) {
      size_t eol = content.find('\n', pos);
      if (eol == std::string::npos) eol = content.size();
      std::string ln = content.substr(pos, eol - pos);
      ++line;
      visitor(file, line, ln);
      pos = eol + 1;
    }
  }
}

/**
 * @brief Scan lines with additional skip-comment support.
 *
 * Skips lines that start with // or are inside block comments.
 */
inline void scan_code_lines(FileSystem& fs, const std::string& dir, const std::string& pattern,
                            std::function<void(const std::string& file, int line, const std::string& ln)> visitor) {
  auto files = fs.find_files(dir, pattern);
  for (auto& file : files) {
    std::string content = fs.read(file);
    int line = 0;
    size_t pos = 0;
    bool in_block_comment = false;
    while (pos < content.size()) {
      size_t eol = content.find('\n', pos);
      if (eol == std::string::npos) eol = content.size();
      std::string ln = content.substr(pos, eol - pos);
      line++;

      // Track block comments
      if (ln.find("/*") != std::string::npos) in_block_comment = true;
      if (ln.find("*/") != std::string::npos) in_block_comment = false;

      // Skip comments
      size_t first_non_space = ln.find_first_not_of(" \t");
      bool is_line_comment = (first_non_space != std::string::npos && ln.substr(first_non_space, 2) == "//");

      if (!in_block_comment && !is_line_comment) {
        visitor(file, line, ln);
      }

      pos = eol + 1;
    }
  }
}

#endif
