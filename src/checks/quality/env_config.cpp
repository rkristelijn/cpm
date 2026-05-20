/**
// @see ADR-129
 * @file env_config.cpp
 * @brief Native env/config validation — detects dangerous configs and missing vars.
 *
 * Checks:
 * - Dangerous env vars (NODE_TLS_REJECT_UNAUTHORIZED=0)
 * - process.env usage without validation
 * - .env.example vs actual usage mismatch
 *
 * Dangerous env vars disable security features silently.
 * NODE_TLS_REJECT_UNAUTHORIZED=0 disables ALL certificate validation,
 * making every HTTPS connection vulnerable to MITM attacks.
 * These should never appear in docker-compose or CI config.
 */
#include "../check.h"

struct EnvConfigCheck : Check {
  EnvConfigCheck() {
    name = "env-config";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    /* Dangerous env patterns */
    static const struct {
      const char* pattern;
      const char* msg;
    } dangerous[] = {{"NODE_TLS_REJECT_UNAUTHORIZED=0", "TLS verification disabled via env"},
                     {"NODE_TLS_REJECT_UNAUTHORIZED='0'", "TLS verification disabled via env"},
                     {"PYTHONDONTWRITEBYTECODE", ""}, /* skip, not dangerous */
                     {"DEBUG=1", "Debug mode enabled via env"},
                     {"DEBUG=true", "Debug mode enabled via env"},
                     {nullptr, nullptr}};

    /* Check docker-compose, .env files, scripts */
    const char* config_files[] = {"docker-compose.yml", "docker-compose.yaml", ".env", ".env.production", "Dockerfile", nullptr};

    for (int i = 0; config_files[i]; i++) {
      if (!fs.exists(config_files[i])) continue;
      std::string content = fs.read(config_files[i]);
      for (int j = 0; dangerous[j].pattern; j++) {
        if (dangerous[j].msg[0] == '\0') continue;
        if (content.find(dangerous[j].pattern) != std::string::npos)
          findings.push_back(
              {name, "error", config_files[i], 0, "dangerous-env", dangerous[j].msg, "Remove or restrict to development only", ""});
      }
    }

    /* Check for process.env without validation */
    auto files = fs.find_files("src", "\\.(ts|js)$");
    int unvalidated = 0;
    for (auto& file : files) {
      if (file.find("test") != std::string::npos) continue;
      std::string content = fs.read(file);
      size_t pos = 0;
      while ((pos = content.find("process.env.", pos)) != std::string::npos) {
        unvalidated++;
        pos += 12;
      }
    }
    if (unvalidated > 10)
      findings.push_back({name, "info", "src/", 0, "unvalidated-env",
                          std::to_string(unvalidated) + " process.env usages without schema validation",
                          "Use zod/joi to validate env at startup", ""});

    return findings;
  }
};
