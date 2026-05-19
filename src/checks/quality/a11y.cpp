/**
 * @file a11y.cpp
 * @brief Native accessibility check — detects WCAG violations in JSX/HTML.
 *
 * Catches the most common accessibility anti-patterns that break
 * keyboard navigation, screen readers, and assistive technology.
 */
#include "../check.h"

struct A11yCheck : Check {
  A11yCheck() {
    name = "a11y";
    category = "quality";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    auto files = fs.find_files("src", "\\.(tsx|jsx|html|vue|svelte)$");

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

        /* div/span with onClick — use button instead */
        if ((ln.find("<div") != std::string::npos || ln.find("<span") != std::string::npos) &&
            (ln.find("onClick") != std::string::npos || ln.find("onclick") != std::string::npos))
          findings.push_back({name, "warning", file, line, "a11y-click-div", "div/span with onClick — not keyboard accessible",
                              "Use <button> or add role='button' + tabIndex + onKeyDown",
                              "https://www.w3.org/WAI/WCAG21/Understanding/keyboard"});

        /* img without alt */
        if (ln.find("<img") != std::string::npos && ln.find("alt") == std::string::npos)
          findings.push_back({name, "warning", file, line, "a11y-img-no-alt", "<img> without alt attribute — invisible to screen readers",
                              "Add alt='description' or alt='' for decorative images",
                              "https://www.w3.org/WAI/WCAG21/Understanding/non-text-content"});

        /* a without href (non-link anchor) */
        if (ln.find("<a") != std::string::npos && ln.find("onClick") != std::string::npos && ln.find("href") == std::string::npos)
          findings.push_back({name, "warning", file, line, "a11y-anchor-no-href", "<a> with onClick but no href — use <button> instead",
                              "Use <button> for actions, <a href> for navigation", ""});

        /* autoFocus — disrupts screen reader flow */
        if (ln.find("autoFocus") != std::string::npos || ln.find("autofocus") != std::string::npos)
          findings.push_back({name, "info", file, line, "a11y-autofocus", "autoFocus disrupts screen reader navigation flow",
                              "Manage focus programmatically when needed", ""});

        /* tabIndex > 0 — breaks natural tab order */
        if (ln.find("tabIndex=") != std::string::npos || ln.find("tabindex=") != std::string::npos) {
          size_t ti = ln.find("tabIndex=");
          if (ti == std::string::npos) ti = ln.find("tabindex=");
          if (ti != std::string::npos) {
            size_t val_start = ti + 10;
            while (val_start < ln.size() && !isdigit(ln[val_start]) && ln[val_start] != '-') val_start++;
            int val = atoi(ln.c_str() + val_start);
            if (val > 0)
              findings.push_back({name, "warning", file, line, "a11y-tabindex-positive", "tabIndex > 0 breaks natural tab order",
                                  "Use tabIndex={0} or tabIndex={-1} only", ""});
          }
        }

        /* Missing form labels */
        if ((ln.find("<input") != std::string::npos || ln.find("<select") != std::string::npos ||
             ln.find("<textarea") != std::string::npos) &&
            ln.find("aria-label") == std::string::npos && ln.find("id=") == std::string::npos &&
            ln.find("aria-labelledby") == std::string::npos && ln.find("placeholder") == std::string::npos)
          findings.push_back(
              {name, "info", file, line, "a11y-no-label", "Form input without label/aria-label", "Add <label htmlFor> or aria-label", ""});

        /* onClick without onKeyDown (keyboard inaccessible) */
        if (ln.find("onClick") != std::string::npos && ln.find("onKeyDown") == std::string::npos &&
            ln.find("onKeyPress") == std::string::npos && ln.find("<button") == std::string::npos && ln.find("<a ") == std::string::npos)
          findings.push_back({name, "info", file, line, "a11y-no-keyboard", "onClick without keyboard handler — not accessible",
                              "Add onKeyDown or use semantic element (<button>)", ""});

        pos = eol + 1;
      }
    }
    return findings;
  }
};
