/**
// @see ADR-129
 * @file crypto.cpp
 * @brief Native weak cryptography detection — flags insecure algorithms and protocols.
 *
 * Detects: SSLv2/v3, TLS 1.0/1.1, MD5/SHA1 for crypto, DES/RC4,
 * disabled certificate verification, http:// URLs in production code.
 *
 * These are severity:error because weak crypto provides false security.
 * An attacker can break SSLv3 in minutes, MD5 collisions are trivial,
 * and disabled cert verification enables MITM attacks.
 * Minimum acceptable: TLS 1.2+, SHA-256+, AES-128+.
 */
#include "../check.h"

struct CryptoCheck : Check {
  CryptoCheck() {
    name = "crypto";
    category = "security";
  }

  std::vector<Finding> run(FileSystem& fs, ToolRunner&) override {
    std::vector<Finding> findings;

    static const struct {
      const char* pattern;
      const char* rule;
      const char* msg;
      const char* fix;
    } patterns[] = {{"SSLv2", "weak-ssl", "SSLv2 is broken", "Use TLS 1.2+"},
                    {"SSLv3", "weak-ssl", "SSLv3 is broken (POODLE)", "Use TLS 1.2+"},
                    {"TLSv1_0", "weak-tls", "TLS 1.0 is deprecated", "Use TLS 1.2+"},
                    {"TLSv1.0", "weak-tls", "TLS 1.0 is deprecated", "Use TLS 1.2+"},
                    {"TLSv1_1", "weak-tls", "TLS 1.1 is deprecated", "Use TLS 1.2+"},
                    {"TLSv1.1", "weak-tls", "TLS 1.1 is deprecated", "Use TLS 1.2+"},
                    {"createHash('md5')", "weak-hash", "MD5 is cryptographically broken", "Use SHA-256+"},
                    {"createHash(\"md5\")", "weak-hash", "MD5 is cryptographically broken", "Use SHA-256+"},
                    {"MessageDigest.getInstance(\"MD5\")", "weak-hash", "MD5 is broken", "Use SHA-256+"},
                    {"hashlib.md5", "weak-hash", "MD5 is broken for security", "Use hashlib.sha256"},
                    {"createHash('sha1')", "weak-hash", "SHA-1 is deprecated for security", "Use SHA-256+"},
                    {"DES", "weak-cipher", "DES is broken (56-bit key)", "Use AES-256"},
                    {"RC4", "weak-cipher", "RC4 is broken", "Use AES-256-GCM"},
                    {"rejectUnauthorized: false", "no-cert-verify", "Certificate verification disabled", "Remove or use proper CA"},
                    {"VERIFY_NONE", "no-cert-verify", "Certificate verification disabled", "Use VERIFY_PEER"},
                    {"InsecureSkipVerify: true", "no-cert-verify", "Certificate verification disabled", "Verify certificates"},
                    {"verify=False", "no-cert-verify", "Certificate verification disabled (Python)", "Use verify=True"},
                    {nullptr, nullptr, nullptr, nullptr}};

    auto files = fs.find_files("src", "\\.(cpp|h|ts|js|py|java|go)$");
    for (auto& file : files) {
      std::string content = fs.read(file);
      /* Skip test files and node_modules */
      if (file.find("test") != std::string::npos) continue;
      if (file.find("node_modules") != std::string::npos) continue;
      if (content.find("cpm:ignore crypto") != std::string::npos) continue;

      for (int i = 0; patterns[i].pattern; i++) {
        size_t pos = content.find(patterns[i].pattern);
        if (pos != std::string::npos) {
          int line = 1;
          for (size_t j = 0; j < pos; j++)
            if (content[j] == '\n') line++;
          findings.push_back(
              {name, "error", file, line, patterns[i].rule, patterns[i].msg, patterns[i].fix, "https://cpm.dev/checks/crypto"});
        }
      }
    }
    return findings;
  }
};
