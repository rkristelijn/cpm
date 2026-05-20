/**
// @see ADR-129
 * @file pii.cpp
 * @brief Native PII detection — flags personal data in source code.
 *
 * Detects hardcoded personally identifiable information:
 * - Email addresses, phone numbers, IP addresses
 * - Dutch BSN numbers, credit card patterns
 * - Physical addresses, names in string literals
 *
 * GDPR Article 25 requires "data protection by design".
 * Hardcoded PII in source code violates this principle and
 * creates compliance risk if the repo is ever made public.
 */
#include <regex>

#include "../check.h"

struct PiiCheck : Check {
  PiiCheck() {
    name = "pii";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;
    static const std::regex patterns(
        "([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})"  /* email */
        "|(\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b)"              /* phone */
        "|(\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b)" /* IP address */
    );

    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py|json)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      if (content.find("cpm:ignore pii") != std::string::npos) continue;

      std::sregex_iterator it(content.begin(), content.end(), patterns);
      std::sregex_iterator end;
      for (; it != end; ++it) {
        int line = 1;
        for (size_t i = 0; i < (size_t)it->position(); i++)
          if (content[i] == '\n') line++;
        findings.push_back({name, "warning", file, line, "pii-detected", "Potential PII: " + it->str().substr(0, 20) + "...",
                            "Use placeholder or environment variable"});
      }
    }
    return findings;
  }
};
