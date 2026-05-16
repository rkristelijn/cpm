/**
 * @file web_quality.cpp
 * @brief Web quality check — SEO, bundle size, reinvented wheels, logging smells.
 */
#include "check.h"

struct WebQualityCheck : Check {
  WebQualityCheck() { name = "web-quality"; category = "quality"; }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(tsx|jsx|html|vue|ts|js)$");

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

        /* === SEO === */
        /* Page/layout without meta tags */
        if ((file.find("page") != std::string::npos || file.find("layout") != std::string::npos ||
             file.find("index.html") != std::string::npos) && line == 1) {
          if (content.find("<title") == std::string::npos && content.find("metadata") == std::string::npos &&
              content.find("Head") == std::string::npos && content.find("<meta") == std::string::npos)
            findings.push_back({name, "info", file, 0, "seo-no-meta",
                "Page without title/meta tags — bad for SEO",
                "Add <title>, meta description, og:tags", ""});
        }

        /* === Reinventing the wheel: dates === */
        if (ln.find("new Date(") != std::string::npos && (
            ln.find("getMonth()") != std::string::npos || ln.find("getFullYear()") != std::string::npos ||
            ln.find("toLocaleDateString") != std::string::npos))
          findings.push_back({name, "info", file, line, "reinvent-dates",
              "Manual date manipulation — use date-fns or dayjs",
              "Avoid raw Date API for formatting/parsing", ""});

        /* Date arithmetic (adding days manually) */
        if (ln.find("86400000") != std::string::npos || ln.find("* 24 * 60 * 60") != std::string::npos)
          findings.push_back({name, "info", file, line, "reinvent-date-math",
              "Manual date arithmetic (ms calculation)",
              "Use date-fns addDays() or dayjs().add()", ""});

        /* === Reinventing i18n === */
        if ((ln.find("language === ") != std::string::npos || ln.find("locale === ") != std::string::npos) &&
            content.find("i18n") == std::string::npos && content.find("intl") == std::string::npos)
          findings.push_back({name, "info", file, line, "reinvent-i18n",
              "Manual language switching — use i18n library",
              "Use next-intl, react-i18next, or @angular/localize", ""});

        /* === Logging smells === */
        /* console.log in production code */
        if (ln.find("console.log(") != std::string::npos &&
            file.find("debug") == std::string::npos && file.find("logger") == std::string::npos)
          findings.push_back({name, "info", file, line, "console-log-prod",
              "console.log in production code",
              "Use structured logger (pino, winston)", ""});

        /* JSON.stringify in logging (expensive) */
        if (ln.find("console.") != std::string::npos && ln.find("JSON.stringify") != std::string::npos)
          findings.push_back({name, "warning", file, line, "log-json-stringify",
              "JSON.stringify in log statement — expensive at scale",
              "Use structured logger that handles serialization", ""});

        /* === Dead links in JSX === */
        if (ln.find("href=\"#\"") != std::string::npos || ln.find("href='#'") != std::string::npos)
          findings.push_back({name, "info", file, line, "dead-link",
              "href='#' — dead link or placeholder",
              "Use proper route or button for actions", ""});

        /* === Bundle size smells === */
        /* Importing entire lodash */
        if (ln.find("import lodash") != std::string::npos || ln.find("require('lodash')") != std::string::npos ||
            ln.find("from 'lodash'") != std::string::npos)
          findings.push_back({name, "warning", file, line, "bundle-lodash-full",
              "Importing full lodash (~70KB) — use lodash-es or lodash/specific",
              "import { map } from 'lodash-es' or import map from 'lodash/map'", ""});

        /* Importing moment.js (huge, deprecated) */
        if (ln.find("from 'moment'") != std::string::npos || ln.find("require('moment')") != std::string::npos)
          findings.push_back({name, "warning", file, line, "bundle-moment",
              "moment.js is 300KB+ and deprecated",
              "Use date-fns (tree-shakeable) or dayjs (2KB)", ""});

        pos = eol + 1;
      }
    }
    return findings;
  }
};
