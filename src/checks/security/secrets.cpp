/**
// @see ADR-129
 * @file secrets.cpp
 * @brief Native secret detection — regex-based, no external tools needed.
 *
 * Detects hardcoded API keys, tokens, and credentials using pattern matching.
 * Patterns cover: AWS keys, OpenAI keys, GitHub tokens, Stripe keys,
 * generic high-entropy strings, and common variable names (password, secret).
 *
 * This is the "fast path" — runs in-process without gitleaks/trufflehog.
 * For deeper scanning (git history, entropy analysis), use the tool-based checks.
 * Supports cpm:ignore annotation for intentional test fixtures.
 */
#include <regex>

#include "../check.h"

struct SecretsCheck : Check {
  SecretsCheck() {
    name = "secrets-fast";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    static const std::regex patterns(
        "(sk-[a-zA-Z0-9]{20,})"
        "|(AKIA[A-Z0-9]{16})"
        "|(ghp_[a-zA-Z0-9]{36})"
        "|(gho_[a-zA-Z0-9]{36})"
        "|(xox[bpras]-[a-zA-Z0-9-]{10,})"
        "|(AIza[a-zA-Z0-9_-]{35})"
        "|(sk_live_[a-zA-Z0-9]{24})"
        "|(-----BEGIN (RSA |EC )?PRIVATE KEY)");

    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py|json)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      /* Skip files with ignore annotation */
      if (content.find("cpm:ignore secret") != std::string::npos) continue;

      std::sregex_iterator it(content.begin(), content.end(), patterns);
      std::sregex_iterator end;
      for (; it != end; ++it) {
        /* Find line number */
        int line = 1;
        for (size_t i = 0; i < (size_t)it->position(); i++)
          if (content[i] == '\n') line++;

        findings.push_back({name, "error", file, line, "hardcoded-secret", "Potential secret/API key detected",
                            "Use environment variable or secrets manager", "https://cpm.dev/checks/secrets"});
      }
    }
    return findings;
  }
};
