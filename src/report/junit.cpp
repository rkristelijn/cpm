/**
 * @file junit.cpp
 * @brief JUnit XML renderer — spec-compliant output for CI integration.
 *
 * Produces valid JUnit XML that works with:
 * - GitHub Actions, GitLab CI, Jenkins, Azure DevOps
 * - SonarQube, Testmo, Xray
 *
 * Groups findings by check name into testsuites.
 * Errors → <failure>, warnings → <system-out>, info → passed.
 */
#include "junit.h"

#include <cstdio>
#include <ctime>
#include <map>

std::string xml_escape(const std::string& s) {
  std::string out;
  out.reserve(s.size());
  for (char c : s) {
    switch (c) {
      case '&': out += "&amp;"; break;
      case '<': out += "&lt;"; break;
      case '>': out += "&gt;"; break;
      case '"': out += "&quot;"; break;
      default: out += c;
    }
  }
  return out;
}

static std::string timestamp_now() {
  time_t t = time(nullptr);
  char buf[32];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", localtime(&t));
  return buf;
}

void junit_render(const std::vector<Finding>& findings, const char* suite_name) {
  /* Group by check */
  std::map<std::string, std::vector<const Finding*>> groups;
  for (auto& f : findings) groups[f.check].push_back(&f);

  int total = (int)findings.size();
  int failures = 0, errors = 0, skipped = 0;
  for (auto& f : findings) {
    if (f.severity == "error") failures++;
  }

  std::string ts = timestamp_now();

  printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  printf("<testsuites name=\"%s\" tests=\"%d\" failures=\"%d\" errors=\"%d\" "
         "skipped=\"%d\" time=\"0\" timestamp=\"%s\">\n",
      xml_escape(suite_name).c_str(), total, failures, errors, skipped, ts.c_str());

  for (auto& [check, items] : groups) {
    int suite_failures = 0;
    for (auto* f : items) if (f->severity == "error") suite_failures++;

    printf("  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\" errors=\"0\" skipped=\"0\">\n",
        xml_escape(check).c_str(), (int)items.size(), suite_failures);

    for (auto* f : items) {
      printf("    <testcase name=\"%s\" classname=\"%s\" file=\"%s\" line=\"%d\">\n",
          xml_escape(f->rule).c_str(),
          xml_escape(f->check).c_str(),
          xml_escape(f->file).c_str(),
          f->line);

      if (f->severity == "error") {
        printf("      <failure message=\"%s\" type=\"%s\">\n",
            xml_escape(f->message).c_str(), xml_escape(f->rule).c_str());
        if (!f->fix.empty())
          printf("Fix: %s\n", xml_escape(f->fix).c_str());
        printf("      </failure>\n");
      } else if (f->severity == "warning") {
        printf("      <system-out>WARNING: %s", xml_escape(f->message).c_str());
        if (!f->fix.empty()) printf(" | Fix: %s", xml_escape(f->fix).c_str());
        printf("</system-out>\n");
      }
      /* info = passed (no failure element) */

      printf("    </testcase>\n");
    }
    printf("  </testsuite>\n");
  }
  printf("</testsuites>\n");
}

void junit_render_file(const std::vector<Finding>& findings, const char* suite_name, const char* path) {
  FILE* old_stdout = stdout;
  FILE* f = fopen(path, "w");
  if (!f) return;
  stdout = f;
  junit_render(findings, suite_name);
  stdout = old_stdout;
  fclose(f);
}
