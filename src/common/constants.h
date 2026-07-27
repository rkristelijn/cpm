/**
 * @file constants.h
 * @brief Shared buffer size constants for cpm.
 *
 * Use these instead of raw integer literals in array declarations.
 * Sized to accommodate realistic OS limits with headroom for formatting overhead.
 *
 * @see https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/limits.h.html
 */
#ifndef CPM_CONSTANTS_H
#define CPM_CONSTANTS_H

#include <cstddef>

/** Maximum path length (filesystem path, binary location, config dir). */
constexpr size_t CPM_PATH_MAX = 1024;

/**
 * Maximum shell command length.
 * Must be larger than CPM_PATH_MAX to accommodate paths embedded in commands.
 */
constexpr size_t CPM_CMD_MAX = 2048;

/** Maximum length of a single input line (file reading, popen output). */
constexpr size_t CPM_LINE_MAX = 2048;

/** Maximum length of a human-readable message or finding description. */
constexpr size_t CPM_MSG_MAX = 2048;

/** Maximum length of a short identifier (repo name, check name, slug). */
constexpr size_t CPM_NAME_MAX = 256;

/** Read buffer for popen/fgets output (single tool output line or small chunk). */
constexpr size_t CPM_READ_BUF = 8192;

/** Large read buffer for capturing full tool output in one shot (e.g. full git log). */
constexpr size_t CPM_READ_BUF_LARGE = 65536;

#endif /* CPM_CONSTANTS_H */
