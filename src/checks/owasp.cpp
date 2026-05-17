/**
 * @file owasp.cpp
 * @brief Native OWASP Top 10:2025 detection — regex-based, no tools needed.
 *
 * Covers patterns detectable without deep dataflow analysis:
 * A01 Broken Access Control, A02 Misconfiguration, A05 Injection,
 * A07 Auth Failures, A09 Logging Failures, A10 Exception Handling.
 *
 * For deeper analysis, use semgrep (which has 1000+ OWASP rules).
 */
#include "check.h"

struct OwaspCheck : Check {
  OwaspCheck() {
    name = "owasp";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    static const struct {
      const char* pattern;
      const char* rule;
      const char* msg;
      const char* fix;
      const char* owasp;
    } rules[] = {/* A01: Broken Access Control */
                 {"role === \"admin\"", "a01-hardcoded-role", "Hardcoded role check", "Use RBAC/policy engine", "A01"},
                 {"isAdmin = true", "a01-hardcoded-admin", "Hardcoded admin flag", "Use proper authorization", "A01"},

                 /* A02: Security Misconfiguration */
                 {"debug: true", "a02-debug-enabled", "Debug mode enabled", "Disable in production", "A02"},
                 {"DEBUG = True", "a02-debug-enabled", "Debug mode enabled (Python)", "Set DEBUG=False in prod", "A02"},
                 {"Access-Control-Allow-Origin: *", "a02-cors-wildcard", "CORS allows all origins", "Restrict to specific origins", "A02"},
                 {"cors({ origin: '*'", "a02-cors-wildcard", "CORS allows all origins", "Restrict to specific origins", "A02"},
                 {"cors(origins=['*']", "a02-cors-wildcard", "CORS allows all origins", "Restrict to specific origins", "A02"},
                 {"X-Powered-By", "a02-server-info", "Server technology exposed", "Remove X-Powered-By header", "A02"},
                 {"stack trace", "a02-verbose-error", "Stack trace may leak to users", "Use generic error messages", "A02"},

                 /* A05: Injection */
                 {"` + req.", "a05-sql-concat", "String concatenation in query (potential injection)", "Use parameterized queries", "A05"},
                 {"\" + req.", "a05-sql-concat", "String concatenation with user input", "Use parameterized queries", "A05"},
                 {"f\"SELECT", "a05-sql-fstring", "f-string in SQL (Python injection risk)", "Use parameterized queries", "A05"},
                 {"${req.", "a05-template-injection", "Template literal with request data", "Sanitize input", "A05"},
                 {"innerHTML", "a05-xss", "innerHTML usage (XSS risk)", "Use textContent or sanitize", "A05"},
                 {"dangerouslySetInnerHTML", "a05-xss-react", "dangerouslySetInnerHTML (XSS risk)", "Sanitize with DOMPurify", "A05"},
                 {"document.write", "a05-xss", "document.write (XSS risk)", "Use DOM APIs", "A05"},

                 /* A07: Authentication Failures */
                 {"password = \"", "a07-hardcoded-password", "Hardcoded password", "Use secrets manager", "A07"},
                 {"password: \"", "a07-hardcoded-password", "Hardcoded password", "Use secrets manager", "A07"},
                 {"jwt.decode", "a07-jwt-no-verify", "JWT decoded without verification", "Use jwt.verify()", "A07"},
                 {"algorithm: 'none'", "a07-jwt-none", "JWT with 'none' algorithm", "Use RS256 or ES256", "A07"},
                 {"expiresIn: '365d'", "a07-long-token", "Token expires in 365 days", "Use short-lived tokens + refresh", "A07"},

                 /* A09: Security Logging Failures */
                 {"catch {}", "a09-empty-catch", "Empty catch block (swallowed error)", "Log the error", "A09"},
                 {"catch (e) {}", "a09-empty-catch", "Empty catch block", "Log or handle the error", "A09"},
                 {"except:\n    pass", "a09-bare-except", "Bare except with pass (Python)", "Log the exception", "A09"},

                 /* A10: Exception Handling */
                 {"catch (Exception e)", "a10-catch-all", "Catching generic Exception", "Catch specific exceptions", "A10"},
                 {"catch (Throwable", "a10-catch-all", "Catching Throwable (too broad)", "Catch specific exceptions", "A10"},
                 {"catch (...)", "a10-catch-all-cpp", "Catching all exceptions (C++)", "Catch specific types", "A10"},

                 {nullptr, nullptr, nullptr, nullptr, nullptr}};

    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py|java|go|jsx|tsx)$");
    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      if (file.find("node_modules") != std::string::npos) continue;
      std::string content = fs.read(file);
      if (content.find("cpm:ignore owasp") != std::string::npos) continue;

      for (int i = 0; rules[i].pattern; i++) {
        size_t pos = 0;
        while ((pos = content.find(rules[i].pattern, pos)) != std::string::npos) {
          int line = 1;
          for (size_t j = 0; j < pos; j++)
            if (content[j] == '\n') line++;
          findings.push_back({name, "warning", file, line, rules[i].rule, std::string("[") + rules[i].owasp + "] " + rules[i].msg,
                              rules[i].fix, "https://owasp.org/Top10/"});
          pos += strlen(rules[i].pattern);
        }
      }
    }

    /* A07: Custom authentication detection — use proven libraries instead */
    bool has_auth_lib = false;
    if (fs.exists("package.json")) {
      std::string pkg = fs.read("package.json");
      has_auth_lib = pkg.find("next-auth") != std::string::npos || pkg.find("passport") != std::string::npos ||
                     pkg.find("@auth/") != std::string::npos || pkg.find("lucia") != std::string::npos ||
                     pkg.find("clerk") != std::string::npos || pkg.find("auth0") != std::string::npos ||
                     pkg.find("supabase") != std::string::npos || pkg.find("firebase") != std::string::npos ||
                     pkg.find("keycloak") != std::string::npos || pkg.find("bcrypt") != std::string::npos;
    }
    if (!has_auth_lib) {
      for (auto& file : files) {
        if (file.find("test") != std::string::npos) continue;
        std::string content = fs.read(file);
        /* Signs of rolling your own auth */
        bool custom_auth = false;
        int line = 0;
        if (content.find("comparePassword") != std::string::npos || content.find("hashPassword") != std::string::npos ||
            content.find("createHash") != std::string::npos || content.find("pbkdf2") != std::string::npos ||
            content.find("crypto.createHmac") != std::string::npos) {
          /* Find line */
          size_t pos = content.find("Password");
          if (pos == std::string::npos) pos = content.find("createHash");
          for (size_t i = 0; i < pos && i < content.size(); i++)
            if (content[i] == '\n') line++;
          custom_auth = true;
        }
        if (custom_auth) {
          findings.push_back({name, "warning", file, line, "a07-custom-auth",
                              "[A07] Custom authentication implementation — use a proven library",
                              "Use next-auth, passport, lucia, clerk, or auth0",
                              "https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html"});
          break; /* Only report once */
        }
      }
    }

    return findings;
  }
};
