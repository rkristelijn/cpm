/**
// @see ADR-129
 * @file commands_test.cpp
 * @brief Unit tests for CLI command dispatch.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN

#include <sys/stat.h>
#include <unistd.h>

#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

#include "../../vendor/doctest.h"
#include "commands.h"

namespace {

std::string make_temp_dir() {
  char tmpl[] = "/tmp/cpm_docs_test_XXXXXX";
  char* p = mkdtemp(tmpl);
  REQUIRE(p != nullptr);
  return std::string(p);
}

void write_file(const std::string& path, const std::string& content) {
  std::ofstream out(path);
  out << content;
  out.close();
}

std::string read_all(const std::string& path) {
  std::ifstream in(path);
  std::string all((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
  return all;
}

bool file_exists(const std::string& path) {
  struct stat st;
  return stat(path.c_str(), &st) == 0;
}

// Invoke `cmd_docs` with a vector of args (subcommand + args).
int run_docs(const std::vector<std::string>& args) {
  std::vector<char*> argv;
  for (const auto& a : args) argv.push_back(const_cast<char*>(a.c_str()));
  return cmd_docs(static_cast<int>(argv.size()), argv.data());
}

}  // namespace

TEST_SUITE("commands") {
  SCENARIO("cmd_sort returns error with no arguments") {
    GIVEN("no arguments to cmd_sort") {
      THEN("it returns error code 1") {
        int argc = 0;
        char* argv[] = {nullptr};
        int rc = cmd_sort(argc, argv);
        CHECK(rc == 1);
      }
    }
  }
}

TEST_SUITE("docs-index") {
  SCENARIO("docs index generates an INDEX.md with extracted titles and summaries") {
    GIVEN("a directory of markdown files") {
      std::string dir = make_temp_dir();
      write_file(dir + "/alpha.md", "# Alpha Doc\n\nAlpha summary paragraph.\n");
      write_file(dir + "/beta.md", "---\ntitle: Beta FM\n---\n\n# Ignored\n\nBeta summary.\n");

      WHEN("docs index runs") {
        int rc = run_docs({"index", dir});
        THEN("it succeeds and writes INDEX.md") {
          CHECK(rc == 0);
          CHECK(file_exists(dir + "/INDEX.md"));
          std::string idx = read_all(dir + "/INDEX.md");
          AND_THEN("the H1 title is used when no frontmatter") {
            CHECK(idx.find("[Alpha Doc](alpha.md)") != std::string::npos);
          }
          AND_THEN("frontmatter title overrides the H1") {
            CHECK(idx.find("[Beta FM](beta.md)") != std::string::npos);
            CHECK(idx.find("Ignored") == std::string::npos);
          }
          AND_THEN("the generated marker is present") {
            CHECK(idx.find("<!-- cpm:docs-index:start -->") != std::string::npos);
          }
        }
      }
    }
  }

  SCENARIO("docs index --check detects drift") {
    GIVEN("a generated index") {
      std::string dir = make_temp_dir();
      write_file(dir + "/one.md", "# One\n\nOne summary.\n");
      REQUIRE(run_docs({"index", dir}) == 0);

      WHEN("nothing changed") {
        THEN("--check passes") { CHECK(run_docs({"index", dir, "--check"}) == 0); }
      }

      WHEN("a new file is added") {
        write_file(dir + "/two.md", "# Two\n\nTwo summary.\n");
        THEN("--check fails with drift") { CHECK(run_docs({"index", dir, "--check"}) == 1); }
      }
    }
  }

  SCENARIO("docs index splices into README.md markers, preserving prose") {
    GIVEN("a README with markers and surrounding prose") {
      std::string dir = make_temp_dir();
      write_file(dir + "/README.md",
                 "# Docs\n\nIntro prose.\n\n"
                 "<!-- cpm:docs-index:start -->\n<!-- cpm:docs-index:end -->\n\n## Footer\n");
      write_file(dir + "/x.md", "# X\n\nX summary.\n");

      WHEN("docs index runs") {
        int rc = run_docs({"index", dir});
        THEN("README is updated and prose preserved") {
          CHECK(rc == 0);
          std::string r = read_all(dir + "/README.md");
          CHECK(r.find("Intro prose.") != std::string::npos);
          CHECK(r.find("## Footer") != std::string::npos);
          CHECK(r.find("[X](x.md)") != std::string::npos);
          CHECK(!file_exists(dir + "/INDEX.md"));  // README present → no INDEX.md
        }
      }
    }
  }

  SCENARIO("docs index refuses the repository root") {
    THEN("indexing '.' returns error") { CHECK(run_docs({"index", "."}) == 1); }
  }

  SCENARIO("cmd_docs with no subcommand prints usage and succeeds") {
    THEN("it returns 0") { CHECK(run_docs({}) == 0); }
  }

  SCENARIO("cmd_docs rejects an unknown subcommand") {
    THEN("it returns 1") { CHECK(run_docs({"bogus"}) == 1); }
  }
}
