/**
// @see ADR-129
 * @file api_security.cpp
 * @brief API security + test quality — exposed endpoints, weak tests, playground.
 *
 * Checks for common API security mistakes:
 * - GraphQL playground/introspection enabled in production
 * - Missing rate limiting configuration
 * - Exposed debug endpoints
 * - Tests without assertions (false confidence)
 * - Missing LICENSE file (legal exposure)
 *
 * These map to OWASP API Security Top 10 categories.
 */
#include "../check.h"

struct ApiSecurityCheck : Check {
  ApiSecurityCheck() {
    name = "api-security";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(ts|js|py|java)$");

    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      if (file.find("node_modules") != std::string::npos) continue;
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;

      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        /* GraphQL playground/introspection enabled */
        if (ln.find("playground: true") != std::string::npos || ln.find("playground:true") != std::string::npos)
          findings.push_back({name, "error", file, line, "graphql-playground", "GraphQL Playground enabled — disable in production",
                              "Set playground: false or use env check", ""});
        if (ln.find("introspection: true") != std::string::npos)
          findings.push_back({name, "warning", file, line, "graphql-introspection", "GraphQL introspection enabled — exposes full schema",
                              "Disable in production: introspection: process.env.NODE_ENV !== 'production'", ""});

        /* Routes without auth middleware */
        if ((ln.find("app.get(") != std::string::npos || ln.find("app.post(") != std::string::npos ||
             ln.find("app.put(") != std::string::npos || ln.find("app.delete(") != std::string::npos ||
             ln.find("router.get(") != std::string::npos || ln.find("router.post(") != std::string::npos) &&
            ln.find("auth") == std::string::npos && ln.find("guard") == std::string::npos && ln.find("protect") == std::string::npos &&
            ln.find("middleware") == std::string::npos && ln.find("public") == std::string::npos &&
            ln.find("health") == std::string::npos && ln.find("login") == std::string::npos && ln.find("register") == std::string::npos)
          findings.push_back({name, "info", file, line, "api-no-auth", "Route without visible auth middleware",
                              "Add authentication guard/middleware", ""});

        /* Swagger/OpenAPI exposed without auth */
        if (ln.find("swagger") != std::string::npos && ln.find("setup") != std::string::npos && content.find("auth") == std::string::npos)
          findings.push_back({name, "warning", file, line, "swagger-no-auth", "Swagger UI without authentication — API docs exposed",
                              "Add basic auth or disable in production", ""});

        pos = eol + 1;
      }
    }

    /* Check for missing LICENSE */
    if (!fs.exists("LICENSE") && !fs.exists("LICENSE.md") && !fs.exists("LICENCE"))
      findings.push_back({name, "warning", ".", 0, "no-license", "No LICENSE file — unclear usage rights",
                          "Add MIT, Apache-2.0, or appropriate license", ""});

    return findings;
  }
};

struct TestQualityCheck : Check {
  TestQualityCheck() {
    name = "test-quality";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(test|spec)\\.(ts|js|tsx|jsx)$");

    for (auto& file : files) {
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      int empty_tests = 0;
      int assertions = 0;

      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        /* Empty test (it/test with no assertions) */
        if ((ln.find("it(") != std::string::npos || ln.find("test(") != std::string::npos) && ln.find("skip") == std::string::npos) {
          /* Look ahead for expect/assert in next ~10 lines */
          size_t look = eol + 1;
          bool has_assert = false;
          for (int i = 0; i < 10 && look < content.size(); i++) {
            size_t next_eol = content.find('\n', look);
            if (next_eol == std::string::npos) next_eol = content.size();
            std::string next_ln = content.substr(look, next_eol - look);
            if (next_ln.find("expect") != std::string::npos || next_ln.find("assert") != std::string::npos ||
                next_ln.find("should") != std::string::npos || next_ln.find("CHECK") != std::string::npos) {
              has_assert = true;
              break;
            }
            if (next_ln.find("});") != std::string::npos) break;
            look = next_eol + 1;
          }
          if (!has_assert) empty_tests++;
        }

        /* Count assertions */
        if (ln.find("expect(") != std::string::npos || ln.find("assert") != std::string::npos) assertions++;

        pos = eol + 1;
      }

      if (empty_tests > 0)
        findings.push_back({name, "warning", file, 0, "empty-test",
                            std::to_string(empty_tests) + " test(s) without assertions — tests nothing",
                            "Add expect() or assert() to verify behavior", ""});
    }

    return findings;
  }
};
