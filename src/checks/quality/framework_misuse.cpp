/**
// @see ADR-129
 * @file framework_misuse.cpp
 * @brief RTFM check — detects common framework misuse patterns.
 *
 * Auto-detects which framework is used (from package.json/pom.xml/etc),
 * then checks for the most common "fighting the framework" anti-patterns.
 *
 * Why this exists: framework misuse is the #1 source of bugs in web apps.
 * Developers copy patterns from older versions or different frameworks,
 * leading to subtle bugs (React state mutation, Next.js unnecessary 'use client',
 * NestJS fat controllers, Angular subscription leaks).
 *
 * Each pattern is sourced from official framework docs or migration guides.
 */
#include "../check.h"

struct FrameworkMisuseCheck : Check {
  FrameworkMisuseCheck() {
    name = "framework-misuse";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    /* Detect frameworks from package.json */
    bool has_react = false, has_next = false, has_nest = false;
    bool has_angular = false, has_express = false;
    if (fs.exists("package.json")) {
      std::string pkg = fs.read("package.json");
      has_react = pkg.find("\"react\"") != std::string::npos;
      has_next = pkg.find("\"next\"") != std::string::npos;
      has_nest = pkg.find("\"@nestjs/core\"") != std::string::npos;
      has_angular = pkg.find("\"@angular/core\"") != std::string::npos;
      has_express = pkg.find("\"express\"") != std::string::npos;
    }

    auto files = fs.find_files("src", "\\.(ts|tsx|js|jsx)$");
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

        /* === React === */
        if (has_react) {
          /* State mutation instead of setState */
          if (ln.find(".push(") != std::string::npos && content.find("useState") != std::string::npos &&
              (ln.find("state.") != std::string::npos || ln.find("items.") != std::string::npos))
            findings.push_back({name, "error", file, line, "react-state-mutation", "Direct state mutation (.push) — React won't re-render",
                                "Use setState([...state, item])", "https://react.dev/learn/updating-arrays-in-state"});

          /* useEffect as onChange handler */
          if (ln.find("useEffect(") != std::string::npos) {
            size_t block_end = content.find(");", pos);
            if (block_end != std::string::npos) {
              std::string block = content.substr(pos, block_end - pos);
              if (block.find("setState") != std::string::npos || block.find("set") != std::string::npos)
                if (block.find("fetch") == std::string::npos && block.find("subscribe") == std::string::npos)
                  findings.push_back({name, "info", file, line, "react-useeffect-setstate",
                                      "setState inside useEffect — often a derived state smell", "Compute during render instead",
                                      "https://react.dev/learn/you-might-not-need-an-effect"});
            }
          }
        }

        /* === Next.js === */
        if (has_next) {
          /* use client for everything */
          if (ln.find("'use client'") != std::string::npos || ln.find("\"use client\"") != std::string::npos) {
            /* Check if it actually needs to be client */
            if (content.find("useState") == std::string::npos && content.find("useEffect") == std::string::npos &&
                content.find("onClick") == std::string::npos && content.find("onChange") == std::string::npos)
              findings.push_back({name, "warning", file, line, "nextjs-unnecessary-client",
                                  "'use client' without client-side hooks/events — should be server component",
                                  "Remove 'use client' directive", "https://nextjs.org/docs/app/building-your-application/rendering"});
          }

          /* API route for own data */
          if (file.find("/api/") != std::string::npos && content.find("prisma") != std::string::npos)
            if (content.find("external") == std::string::npos && content.find("webhook") == std::string::npos)
              findings.push_back({name, "info", file, line, "nextjs-unnecessary-api",
                                  "API route with direct DB access — use server component instead", "Access DB directly in page/layout",
                                  "https://nextjs.org/docs/app/building-your-application/data-fetching"});
        }

        /* === NestJS === */
        if (has_nest) {
          /* Business logic in controller */
          if (file.find("controller") != std::string::npos) {
            if (ln.find("findMany") != std::string::npos || ln.find("createQueryBuilder") != std::string::npos ||
                ln.find(".save(") != std::string::npos || ln.find("prisma.") != std::string::npos)
              findings.push_back({name, "warning", file, line, "nest-fat-controller", "Database access in controller — move to service",
                                  "Inject service, call service method", "https://docs.nestjs.com/providers"});
          }
          /* Manual instantiation instead of DI */
          if (ln.find("new ") != std::string::npos && ln.find("Service(") != std::string::npos)
            findings.push_back({name, "warning", file, line, "nest-manual-di", "Manual Service instantiation — use NestJS DI",
                                "Inject via constructor", "https://docs.nestjs.com/fundamentals/custom-providers"});
        }

        /* === Angular === */
        if (has_angular) {
          /* Subscribe without cleanup */
          if (ln.find(".subscribe(") != std::string::npos && content.find("takeUntil") == std::string::npos &&
              content.find("async") == std::string::npos && content.find("unsubscribe") == std::string::npos &&
              content.find("DestroyRef") == std::string::npos)
            findings.push_back({name, "warning", file, line, "angular-subscribe-leak", ".subscribe() without cleanup — memory leak",
                                "Use async pipe or takeUntilDestroyed()", "https://angular.dev/guide/pipes/unwrapping-data"});

          /* bypassSecurityTrust — XSS vector */
          if (ln.find("bypassSecurityTrust") != std::string::npos)
            findings.push_back({name, "error", file, line, "angular-bypass-security",
                                "bypassSecurityTrust* disables Angular's XSS protection", "Sanitize input properly instead of bypassing",
                                "https://angular.dev/guide/security"});

          /* [innerHTML] binding */
          if (ln.find("[innerHTML]") != std::string::npos)
            findings.push_back({name, "warning", file, line, "angular-innerhtml", "[innerHTML] binding — XSS risk if not sanitized",
                                "Use DomSanitizer or avoid dynamic HTML", "https://angular.dev/guide/security#xss"});

          /* Disabled CSRF */
          if (ln.find("withNoXsrfProtection") != std::string::npos)
            findings.push_back({name, "error", file, line, "angular-no-csrf", "XSRF/CSRF protection disabled",
                                "Remove withNoXsrfProtection()", "https://angular.dev/guide/http/security"});
        }

        /* === Express === */
        if (has_express) {
          /* No error handling middleware */
          if (file.find("app") != std::string::npos && ln.find("app.listen") != std::string::npos) {
            if (content.find("err, req, res, next") == std::string::npos && content.find("error") == std::string::npos)
              findings.push_back({name, "warning", file, line, "express-no-error-handler", "No error handling middleware detected",
                                  "Add app.use((err, req, res, next) => ...)", "https://expressjs.com/en/guide/error-handling.html"});
          }
        }

        pos = eol + 1;
      }
    }

    /* === SQL Injection (any project with DB) === */
    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      std::string content = fs.read(file);
      int line = 0;
      size_t pos = 0;
      while (pos < content.size()) {
        size_t eol = content.find('\n', pos);
        if (eol == std::string::npos) eol = content.size();
        std::string ln = content.substr(pos, eol - pos);
        line++;

        /* String interpolation in SQL */
        if ((ln.find("SELECT") != std::string::npos || ln.find("INSERT") != std::string::npos || ln.find("UPDATE") != std::string::npos ||
             ln.find("DELETE") != std::string::npos) &&
            (ln.find("${") != std::string::npos || ln.find("\" +") != std::string::npos || ln.find("' +") != std::string::npos ||
             ln.find("f\"") != std::string::npos))
          findings.push_back({name, "error", file, line, "sql-injection", "SQL with string interpolation — injection risk",
                              "Use parameterized queries ($1, ?, :param)",
                              "https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html"});

        /* Raw query without params */
        if ((ln.find(".query(\"") != std::string::npos || ln.find(".query(`") != std::string::npos ||
             ln.find("execute(\"") != std::string::npos || ln.find("raw(\"") != std::string::npos) &&
            ln.find("${") != std::string::npos)
          findings.push_back({name, "error", file, line, "sql-raw-interpolation",
                              "Raw query with interpolation — use query builder or params", "Use .query('SELECT ...', [params])", ""});

        /* ORM misuse: findAll without limit */
        if ((ln.find("findAll(") != std::string::npos || ln.find("findMany(") != std::string::npos ||
             ln.find(".all()") != std::string::npos) &&
            ln.find("limit") == std::string::npos && ln.find("take") == std::string::npos && ln.find("paginate") == std::string::npos)
          findings.push_back({name, "info", file, line, "orm-no-limit", "Query without limit — may return unbounded results",
                              "Add take/limit/pagination", ""});

        pos = eol + 1;
      }
    }

    /* === UI Framework misuse (detect from package.json) === */
    if (fs.exists("package.json")) {
      std::string pkg = fs.read("package.json");
      bool has_mui = pkg.find("\"@mui/") != std::string::npos;
      bool has_bootstrap = pkg.find("\"bootstrap\"") != std::string::npos || pkg.find("\"react-bootstrap\"") != std::string::npos;
      bool has_tailwind = pkg.find("\"tailwindcss\"") != std::string::npos;

      if (has_mui || has_bootstrap || has_tailwind) {
        for (auto& file : files) {
          if (file.find("test") != std::string::npos) continue;
          std::string content = fs.read(file);

          /* Inline styles when using a design system */
          if (has_mui || has_tailwind) {
            int inline_styles = 0;
            size_t p = 0;
            while ((p = content.find("style={{", p)) != std::string::npos) {
              inline_styles++;
              p += 8;
            }
            if (inline_styles > 5)
              findings.push_back({name, "info", file, 0, "ui-inline-styles",
                                  std::to_string(inline_styles) + " inline styles — use theme/sx/className",
                                  has_mui ? "Use sx prop or styled()" : "Use Tailwind classes", ""});
          }

          /* Mixing CSS frameworks */
          if (has_tailwind && content.find("style={{") != std::string::npos && content.find("className") != std::string::npos)
            if (content.find("style={{") != std::string::npos) {
              /* Only flag if significant mixing */
              int tw = 0, inline_s = 0;
              size_t p = 0;
              while ((p = content.find("className", p)) != std::string::npos) {
                tw++;
                p += 9;
              }
              p = 0;
              while ((p = content.find("style={{", p)) != std::string::npos) {
                inline_s++;
                p += 8;
              }
              if (tw > 3 && inline_s > 3)
                findings.push_back(
                    {name, "info", file, 0, "ui-mixed-styling", "Mixing Tailwind classes + inline styles — pick one approach", "", ""});
            }
        }
      }
    }

    return findings;
  }
};
