/**
// @see ADR-140
 * @file compliance.h
 * @brief Compliance framework mapping for scan findings.
 *
 * Maps finding rules to ISO 27001, OWASP, CMMI, GDPR, WCAG, SOC 2.
 */
#ifndef CPM_COMPLIANCE_H
#define CPM_COMPLIANCE_H

#include <string>
#include <unordered_map>

inline const std::unordered_map<std::string, const char*>& get_compliance_tags() {
  static const std::unordered_map<std::string, const char*> tags = {
      // Security → ISO 27001 + OWASP + SOC 2
      {"env-committed", "ISO27001:A.9.4.3,OWASP:A3,SOC2:CC6.1"},
      {"hardcoded-secret", "ISO27001:A.9.4.3,OWASP:A3,SOC2:CC6.1"},
      {"eval", "ISO27001:A.14.2.5,OWASP:A3,SOC2:CC7.1"},
      {"pii-detected", "GDPR:Art.25,ISO27001:A.18.1.4,SOC2:CC6.5"},
      {"zero-width-char", "ISO27001:A.14.2.5,OWASP:A3"},

      // Process → CMMI + ISO 27001
      {"no-ci-pipeline", "CMMI:ML2,ISO27001:A.14.2.8"},
      {"no-build-system", "CMMI:ML2"},
      {"no-gitignore", "CMMI:ML1"},
      {"no-editorconfig", "CMMI:ML2"},
      {"no-security-policy", "CMMI:ML2,ISO27001:A.6.1.1,GDPR:Art.33"},
      {"no-issue-templates", "CMMI:ML3"},
      {"no-pr-template", "CMMI:ML3"},
      {"lottery-factor-1", "CMMI:ML2,ISO27001:A.7.2.2"},
      {"high-churn", "CMMI:ML3"},
      {"large-commit", "CMMI:ML3"},
      {"stale-repo", "CMMI:ML1,ISO27001:A.12.6.1"},

      // Quality → ISO 25010 + CMMI
      {"no-tests", "ISO25010:Reliability,CMMI:ML2"},
      {"no-test-script", "ISO25010:Reliability,CMMI:ML2"},
      {"high-complexity", "ISO25010:Maintainability,CMMI:ML3"},
      {"low-comment-ratio", "ISO25010:Maintainability,CMMI:ML3"},
      {"large-file", "ISO25010:Maintainability,CMMI:ML2"},
      {"mock-boundary-violation", "ISO25010:Testability,CMMI:ML3"},

      // Dependencies
      {"unpinned-deps", "ISO27001:A.14.2.1,SOC2:CC7.1"},
      {"no-lockfile", "ISO27001:A.14.2.1,SOC2:CC7.1"},
      {"node-eol", "ISO27001:A.12.6.1,SOC2:CC7.1"},
      {"python-eol", "ISO27001:A.12.6.1,SOC2:CC7.1"},
      {"java-eol", "ISO27001:A.12.6.1,SOC2:CC7.1"},
      {"php-eol", "ISO27001:A.12.6.1,SOC2:CC7.1"},

      // Community/Docs → CMMI
      {"missing-license", "CMMI:ML1"},
      {"missing-readme", "CMMI:ML1,ISO25010:Usability"},
      {"low-readme-score", "CMMI:ML2,ISO25010:Usability"},
      {"default-readme", "CMMI:ML1,ISO25010:Usability"},
      {"no-contributing", "CMMI:ML2,ISO25010:Maintainability"},
      {"no-agent-config", "CMMI:ML3,ISO25010:Maintainability"},

      // Accessibility → WCAG
      {"missing-alt", "WCAG:1.1.1:A"},
      {"missing-label", "WCAG:1.3.1:A"},
      {"low-contrast", "WCAG:1.4.3:AA"},
      {"no-focus-visible", "WCAG:2.4.7:AA"},
      {"no-aria-role", "WCAG:4.1.2:A"},
      {"no-lang-attr", "WCAG:3.1.1:A"},

      // Inclusivity
      {"non-inclusive-term", "WCAG:3.1.4,ISO25010:Usability"},

      // Framework EOL
      {"react-eol", "ISO27001:A.12.6.1"},
      {"vue-eol", "ISO27001:A.12.6.1"},
      {"nextjs-eol", "ISO27001:A.12.6.1"},
      {"typescript-eol", "ISO27001:A.12.6.1"},
      {"terraform-eol", "ISO27001:A.12.6.1"},

      // GitLab CI
      {"deprecated-only-except", "CMMI:ML3"},
      {"latest-image-tag", "ISO27001:A.14.2.1,SOC2:CC7.1"},
      {"no-interruptible", "CMMI:ML3"},
  };
  return tags;
}

#endif
