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
  double total_time = 0;
  for (auto& f : findings) {
    if (f.severity == "error") failures++;
    total_time += f.duration;
  }

  std::string ts = timestamp_now();

  printf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  printf("<testsuites name=\"%s\" tests=\"%d\" failures=\"%d\" errors=\"%d\" "
         "skipped=\"%d\" time=\"%.3f\" timestamp=\"%s\">\n",
      xml_escape(suite_name).c_str(), total, failures, errors, skipped, total_time, ts.c_str());

  for (auto& [check, items] : groups) {
    int suite_failures = 0;
    for (auto* f : items) if (f->severity == "error") suite_failures++;

    printf("  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\" errors=\"0\" skipped=\"0\">\n",
        xml_escape(check).c_str(), (int)items.size(), suite_failures);

    for (auto* f : items) {
      printf("    <testcase name=\"%s\" classname=\"%s\" file=\"%s\" line=\"%d\" time=\"%.3f\">\n",
          xml_escape(f->rule).c_str(),
          xml_escape(f->check).c_str(),
          xml_escape(f->file).c_str(),
          f->line,
          f->duration);

      /* Properties: always include all available context */
      printf("      <properties>\n");
      printf("        <property name=\"severity\" value=\"%s\"/>\n", xml_escape(f->severity).c_str());
      printf("        <property name=\"file\" value=\"%s\"/>\n", xml_escape(f->file).c_str());
      printf("        <property name=\"line\" value=\"%d\"/>\n", f->line);
      if (!f->fix.empty())
        printf("        <property name=\"fix\" value=\"%s\"/>\n", xml_escape(f->fix).c_str());
      if (!f->docs.empty())
        printf("        <property name=\"docs\" value=\"%s\"/>\n", xml_escape(f->docs).c_str());
      printf("      </properties>\n");

      if (f->severity == "error") {
        printf("      <failure message=\"%s\" type=\"%s\">\n",
            xml_escape(f->message).c_str(), xml_escape(f->rule).c_str());
        printf("%s:%d: %s\n", xml_escape(f->file).c_str(), f->line, xml_escape(f->message).c_str());
        if (!f->fix.empty()) printf("Fix: %s\n", xml_escape(f->fix).c_str());
        if (!f->docs.empty()) printf("Docs: %s\n", xml_escape(f->docs).c_str());
        printf("      </failure>\n");
      } else if (f->severity == "warning") {
        printf("      <system-out>%s:%d: %s",
            xml_escape(f->file).c_str(), f->line, xml_escape(f->message).c_str());
        if (!f->fix.empty()) printf("\nFix: %s", xml_escape(f->fix).c_str());
        if (!f->docs.empty()) printf("\nDocs: %s", xml_escape(f->docs).c_str());
        printf("</system-out>\n");
      }
      /* info severity = passed test (no failure/system-out) */

      printf("    </testcase>\n");
    }
    printf("  </testsuite>\n");
  }

  /* Summary testsuite — always present, standardized overview */
  int passed = total - failures - errors - skipped;
  printf("  <testsuite name=\"cpm-summary\" tests=\"4\" failures=\"0\" errors=\"0\">\n");
  printf("    <testcase name=\"total-findings\" classname=\"summary\" time=\"%.3f\">\n", total_time);
  printf("      <system-out>%d finding(s) across %d check(s)</system-out>\n", total, (int)groups.size());
  printf("    </testcase>\n");
  printf("    <testcase name=\"errors\" classname=\"summary\" time=\"0\">\n");
  if (failures > 0)
    printf("      <failure message=\"%d error(s) require attention\" type=\"summary\"/>\n", failures);
  printf("    </testcase>\n");
  printf("    <testcase name=\"warnings\" classname=\"summary\" time=\"0\">\n");
  printf("      <system-out>%d warning(s)</system-out>\n", total - failures);
  printf("    </testcase>\n");
  printf("    <testcase name=\"duration\" classname=\"summary\" time=\"%.3f\">\n", total_time);
  printf("      <system-out>Total: %.3fs</system-out>\n", total_time);
  printf("    </testcase>\n");
  printf("  </testsuite>\n");

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
