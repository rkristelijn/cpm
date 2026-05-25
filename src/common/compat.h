/**
 * @file compat.h
 * @brief Cross-platform compatibility shims for POSIX/Windows.
 */
#pragma once

#ifdef _WIN32
#include <direct.h>
#include <io.h>
#include <process.h>
#define getcwd _getcwd
#define access _access
#define popen _popen
#define pclose _pclose
#define F_OK 0
#else
#include <unistd.h>
#endif
