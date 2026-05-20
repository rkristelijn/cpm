/**
// @see ADR-139
 * @file learn.h
 * @brief Learning resources linked to scan findings.
 * @see ADR-139, free-programming-books
 *
 * Maps finding rules to free learning resources so developers
 * get actionable education alongside warnings.
 */
#ifndef CPM_LEARN_H
#define CPM_LEARN_H

#include <string>
#include <unordered_map>

struct LearnResource {
  const char* title;
  const char* url;
};

// Rule → recommended free resource
inline const std::unordered_map<std::string, LearnResource>& get_learn_links() {
  static const std::unordered_map<std::string, LearnResource> links = {
      // === Community & Open Source ===
      {"no-contributing", {"Producing Open Source Software", "https://producingoss.com"}},
      {"missing-license", {"Choose a License", "https://choosealicense.com"}},
      {"no-security-policy", {"OWASP Testing Guide", "https://owasp.org/www-project-web-security-testing-guide/v42/"}},
      {"no-agent-config", {"Claude Code docs", "https://docs.anthropic.com/en/docs/claude-code"}},

      // === Architecture & Quality ===
      {"no-editorconfig", {"EditorConfig", "https://editorconfig.org"}},
      {"no-tests", {"Software Engineering at Google (Ch.11: Testing)", "https://abseil.io/resources/swe-book/html/ch11.html"}},
      {"no-build-system", {"Software Engineering at Google (Ch.18: Build Systems)", "https://abseil.io/resources/swe-book/html/ch18.html"}},
      {"no-ci-pipeline", {"Software Engineering at Google (Ch.23: CI)", "https://abseil.io/resources/swe-book/html/ch23.html"}},

      // === Code Review & Process ===
      {"no-pr-template",
       {"Best Kept Secrets of Peer Code Review", "https://smartbear.com/lp/ebook/collaborator/secrets-of-peer-code-review/"}},
      {"no-issue-templates", {"The Art of Community (Ch.4)", "https://artofcommunityonline.org/Art_of_Community_Second_Edition.pdf"}},

      // === Security ===
      {"env-committed", {"How HTTPS Works + Secrets Management", "https://howhttps.works"}},
      {"hardcoded-secret", {"OWASP Top 10", "https://owasp.org/www-project-top-ten/"}},

      // === Dependencies ===
      {"unpinned-deps", {"Producing Open Source Software (Ch.7: Packaging)", "https://producingoss.com/en/packaging.html"}},
      {"no-lockfile",
       {"Software Engineering at Google (Ch.21: Dependency Management)", "https://abseil.io/resources/swe-book/html/ch21.html"}},

      // === Git ===
      {"stale-repo", {"Git From The Bottom Up", "https://jwiegley.github.io/git-from-the-bottom-up/"}},
      {"bus-factor-1",
       {"Producing Open Source Software (Ch.8: Managing Participants)", "https://producingoss.com/en/managing-participants.html"}},
      {"lottery-factor-1",
       {"Producing Open Source Software (Ch.8: Managing Participants)", "https://producingoss.com/en/managing-participants.html"}},
      {"high-churn",
       {"Software Engineering at Google (Ch.22: Large-Scale Changes)", "https://abseil.io/resources/swe-book/html/ch22.html"}},
      {"large-commit", {"Software Engineering at Google (Ch.9: Code Review)", "https://abseil.io/resources/swe-book/html/ch09.html"}},

      // === Docs ===
      {"low-readme-score", {"The Art of README", "https://github.com/hackergrrl/art-of-readme"}},
      {"default-readme", {"The Art of README", "https://github.com/hackergrrl/art-of-readme"}},

      // === Framework EOL ===
      {"node-eol", {"Node.js Release Schedule", "https://nodejs.org/en/about/previous-releases"}},
      {"python-eol", {"Python Release Cycle", "https://devguide.python.org/versions/"}},
      {"typescript-eol", {"TypeScript Release Notes", "https://www.typescriptlang.org/docs/handbook/release-notes/overview.html"}},
      {"react-eol", {"React Blog", "https://react.dev/blog"}},
      {"vue-eol", {"Vue 3 Migration Guide", "https://v3-migration.vuejs.org"}},
      {"nextjs-eol", {"Next.js Upgrading Guide", "https://nextjs.org/docs/upgrading"}},
      {"java-eol", {"Java Release Roadmap", "https://www.oracle.com/java/technologies/java-se-support-roadmap.html"}},
      {"php-eol", {"PHP Supported Versions", "https://www.php.net/supported-versions.php"}},
      {"terraform-eol", {"OpenTofu", "https://opentofu.org"}},

      // === CI/CD ===
      {"no-cache", {"GitLab CI Caching", "https://docs.gitlab.com/ci/caching/"}},
      {"no-artifacts", {"GitLab CI Artifacts", "https://docs.gitlab.com/ci/testing/unit_test_reports/"}},
      {"deprecated-only-except", {"GitLab CI Rules", "https://docs.gitlab.com/ci/yaml/#rules"}},
  };
  return links;
}

#endif
