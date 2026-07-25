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

/** Maximum path length (filesystem path, binary location, config dir). */
#define CPM_PATH_MAX  1024

/**
 * Maximum shell command length.
 * Must be larger than CPM_PATH_MAX to accommodate paths embedded in commands.
 */
#define CPM_CMD_MAX   2048

/** Maximum length of a single input line (file reading, popen output). */
#define CPM_LINE_MAX  2048

/** Maximum length of a human-readable message or finding description. */
#define CPM_MSG_MAX   2048

/** Maximum length of a short identifier (repo name, check name, slug). */
#define CPM_NAME_MAX  256

/** Read buffer for popen/fgets output (single tool output line or small chunk). */
#define CPM_READ_BUF       8192

/** Large read buffer for capturing full tool output in one shot (e.g. full git log). */
#define CPM_READ_BUF_LARGE 65536

#endif /* CPM_CONSTANTS_H */
