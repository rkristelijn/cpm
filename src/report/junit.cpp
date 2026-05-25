/**
// @see ADR-129
 * @file junit.cpp
 * @brief JUnit XML builder — object model with clean serialization.
 */
#include "junit.h"

#include <ctime>
#include <map>

static std::string xml_esc(const std::string& s) {
  std::string out;
  out.reserve(s.size());
  for (char c : s) {
    switch (c) {
      case '&':
        out += "&amp;";
        break;
      case '<':
        out += "&lt;";
        break;
      case '>':
        out += "&gt;";
        break;
      case '"':
        out += "&quot;";
        break;
      default:
        out += c;
    }
  }
  return out;
}

/* --- JUnitTestSuite --- */

JUnitTestCase& JUnitTestSuite::add_pass(const std::string& n, const std::string& file, int line, double time) {
  cases.push_back({n, name, file, line, time, "passed", "", "", "", {}});
  return cases.back();
}

JUnitTestCase& JUnitTestSuite::add_failure(const std::string& n, const std::string& file, int line, double time, const std::string& msg,
                                           const std::string& fix, const std::string& docs) {
  cases.push_back({n, name, file, line, time, "failure", msg, fix, docs, {}});
  return cases.back();
}

JUnitTestCase& JUnitTestSuite::add_warning(const std::string& n, const std::string& file, int line, double time, const std::string& msg,
                                           const std::string& fix, const std::string& docs) {
  cases.push_back({n, name, file, line, time, "warning", msg, fix, docs, {}});
  return cases.back();
}

JUnitTestCase& JUnitTestSuite::add_skipped(const std::string& n, const std::string& msg) {
  cases.push_back({n, name, "", 0, 0, "skipped", msg, "", "", {}});
  return cases.back();
}

int JUnitTestSuite::failures() const {
  int n = 0;
  for (auto& c : cases)
    if (c.status == "failure") n++;
  return n;
}

double JUnitTestSuite::total_time() const {
  double t = 0;
  for (auto& c : cases) t += c.time;
  return t;
}

/* --- JUnit --- */

JUnitTestSuite& JUnit::add_suite(const std::string& n) {
  suites.push_back({n, {}});
  return suites.back();
}

int JUnit::total_tests() const {
  int n = 0;
  for (auto& s : suites) n += s.tests();
  return n;
}

int JUnit::total_failures() const {
  int n = 0;
  for (auto& s : suites) n += s.failures();
  return n;
}

double JUnit::total_time() const {
  double t = 0;
  for (auto& s : suites) t += s.total_time();
  return t;
}

JUnit JUnit::from_findings(const std::vector<Finding>& findings, const std::string& name) {
  JUnit report(name);
  std::map<std::string, JUnitTestSuite*> groups;

  for (auto& f : findings) {
    if (!groups.count(f.check)) {
      report.add_suite(f.check);
      groups[f.check] = &report.suites.back();
    }
    auto* suite = groups[f.check];
    if (f.severity == "error")
      suite->add_failure(f.rule, f.file, f.line, f.duration, f.message, f.fix, f.docs);
    else if (f.severity == "warning")
      suite->add_warning(f.rule, f.file, f.line, f.duration, f.message, f.fix, f.docs);
    else
      suite->add_pass(f.rule, f.file, f.line, f.duration);
  }

  /* Always add summary suite */
  auto& summary = report.add_suite("cpm-summary");
  char buf[128];
  snprintf(buf, sizeof(buf), "%d finding(s) across %d check(s)", (int)findings.size(), (int)groups.size());
  summary.add_pass("total", ".", 0, report.total_time()).message = buf;
  if (report.total_failures() > 0) {
    snprintf(buf, sizeof(buf), "%d error(s) require attention", report.total_failures());
    summary.add_failure("errors", ".", 0, 0, buf);
  } else {
    summary.add_pass("errors", ".", 0, 0);
  }

  return report;
}

void JUnit::write(FILE* out) const {
  time_t t = time(nullptr);
  char ts[32];
  struct tm tm_buf; localtime_r(&t, &tm_buf); strftime(ts, sizeof(ts), "%Y-%m-%dT%H:%M:%S", &tm_buf);

  fprintf(out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  fprintf(out,
          "<testsuites name=\"%s\" tests=\"%d\" failures=\"%d\" errors=\"0\" "
          "skipped=\"0\" time=\"%.3f\" timestamp=\"%s\">\n",
          xml_esc(name).c_str(), total_tests(), total_failures(), total_time(), ts);

  for (auto& suite : suites) {
    fprintf(out, "  <testsuite name=\"%s\" tests=\"%d\" failures=\"%d\" time=\"%.3f\">\n", xml_esc(suite.name).c_str(), suite.tests(),
            suite.failures(), suite.total_time());

    for (auto& tc : suite.cases) {
      fprintf(out, "    <testcase name=\"%s\" classname=\"%s\" file=\"%s\" line=\"%d\" time=\"%.3f\">\n", xml_esc(tc.name).c_str(),
              xml_esc(tc.classname).c_str(), xml_esc(tc.file).c_str(), tc.line, tc.time);

      /* Properties */
      if (!tc.fix.empty() || !tc.docs.empty()) {
        fprintf(out, "      <properties>\n");
        if (!tc.fix.empty()) fprintf(out, "        <property name=\"fix\" value=\"%s\"/>\n", xml_esc(tc.fix).c_str());
        if (!tc.docs.empty()) fprintf(out, "        <property name=\"docs\" value=\"%s\"/>\n", xml_esc(tc.docs).c_str());
        fprintf(out, "      </properties>\n");
      }

      /* Status */
      if (tc.status == "failure") {
        fprintf(out, "      <failure message=\"%s\" type=\"%s\">\n", xml_esc(tc.message).c_str(), xml_esc(tc.name).c_str());
        fprintf(out, "%s:%d: %s\n", xml_esc(tc.file).c_str(), tc.line, xml_esc(tc.message).c_str());
        if (!tc.fix.empty()) fprintf(out, "Fix: %s\n", xml_esc(tc.fix).c_str());
        if (!tc.docs.empty()) fprintf(out, "Docs: %s\n", xml_esc(tc.docs).c_str());
        fprintf(out, "      </failure>\n");
      } else if (tc.status == "warning") {
        fprintf(out, "      <system-out>%s:%d: %s", xml_esc(tc.file).c_str(), tc.line, xml_esc(tc.message).c_str());
        if (!tc.fix.empty()) fprintf(out, "\nFix: %s", xml_esc(tc.fix).c_str());
        if (!tc.docs.empty()) fprintf(out, "\nDocs: %s", xml_esc(tc.docs).c_str());
        fprintf(out, "</system-out>\n");
      } else if (tc.status == "skipped") {
        fprintf(out, "      <skipped message=\"%s\"/>\n", xml_esc(tc.message).c_str());
      }

      fprintf(out, "    </testcase>\n");
    }
    fprintf(out, "  </testsuite>\n");
  }
  fprintf(out, "</testsuites>\n");
}

void JUnit::write_file(const std::string& path) const {
  FILE* f = fopen(path.c_str(), "w");
  if (!f) return;
  write(f);
  fclose(f);
}
