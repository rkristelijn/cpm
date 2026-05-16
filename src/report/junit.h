/**
 * @file junit.h
 * @brief JUnit XML renderer — generates spec-compliant JUnit reports.
 *
 * Follows the common JUnit XML format as documented at:
 * https://github.com/testmoapp/junitxml
 *
 * Supports: testsuites, testsuite, testcase, failure, error, skipped, properties.
 */
#ifndef CPM_REPORT_JUNIT_H
#define CPM_REPORT_JUNIT_H

#include <string>
#include <vector>

#include "../checks/check.h"

/** @brief Render findings as JUnit XML to stdout. */
void junit_render(const std::vector<Finding>& findings, const char* suite_name);

/** @brief Render findings as JUnit XML to a file. */
void junit_render_file(const std::vector<Finding>& findings, const char* suite_name, const char* path);

/** @brief XML-escape a string. */
std::string xml_escape(const std::string& s);

#endif
