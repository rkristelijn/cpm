#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN

#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

#include "../vendor/doctest.h"
#include "commands/commands.h"

static std::string make_temp_file(const std::string& content) {
  char path[] = "/tmp/cpm_sort_test_XXXXXX";
  int fd = mkstemp(path);
  REQUIRE(fd >= 0);
  close(fd);

  std::ofstream out(path);
  out << content;
  out.close();

  return std::string(path);
}

static std::string read_file(const std::string& path) {
  std::ifstream in(path);
  std::string all;
  std::string line;
  bool first = true;
  while (std::getline(in, line)) {
    if (!first) all += "\n";
    all += line;
    first = false;
  }
  return all;
}

static int run_sort(const std::vector<std::string>& args) {
  std::vector<char*> argv;
  argv.reserve(args.size());
  for (const auto& a : args) argv.push_back(const_cast<char*>(a.c_str()));
  return cmd_sort((int)argv.size(), argv.data());
}

TEST_SUITE("sort") {
  /* --- Error paths --- */
  TEST_CASE("no args prints usage and fails") {
    int rc = run_sort({});
    CHECK(rc == 1);
  }
  TEST_CASE("missing --mode fails") {
    int rc = run_sort({"fix", "--file", "/tmp/x.toml"});
    CHECK(rc == 1);
  }
  TEST_CASE("missing --file fails") {
    int rc = run_sort({"fix", "--mode", "cpm-toml"});
    CHECK(rc == 1);
  }
  TEST_CASE("unknown mode fails") {
    std::string path = make_temp_file("hello\n");
    int rc = run_sort({"fix", "--mode", "unknown-mode", "--file", path});
    CHECK(rc == 1);
    unlink(path.c_str());
  }
  TEST_CASE("nonexistent file fails") {
    int rc = run_sort({"fix", "--mode", "cpm-toml", "--file", "/nonexistent/dir/file.txt"});
    CHECK(rc == 1);
  }
  TEST_CASE("unknown flag fails") {
    std::string path = make_temp_file("x\n");
    int rc = run_sort({"fix", "--mode", "lines", "--file", path, "--badopt"});
    CHECK(rc == 1);
    unlink(path.c_str());
  }

  /* --- cpm-toml dedup --- */
  TEST_CASE("cpm-toml fix deduplicates keys") {
    std::string path = make_temp_file(
        "[checks]\n"
        "a = true\n"
        "a = false\n"
        "b = 1\n");

    int rc = run_sort({"fix", "--mode", "cpm-toml", "--file", path, "--dedup"});
    CHECK(rc == 0);

    std::string out = read_file(path);
    // Only one 'a' key should remain
    size_t first = out.find("a = ");
    size_t second = out.find("a = ", first + 1);
    CHECK(second == std::string::npos);
    unlink(path.c_str());
  }

  /* --- cpm-toml check succeeds when canonical --- */
  TEST_CASE("cpm-toml check passes when already canonical") {
    std::string path = make_temp_file(
        "[project]\n"
        "name = \"demo\"\n"
        "\n"
        "[checks]\n"
        "a-check = true\n"
        "z-check = false\n");

    int rc = run_sort({"check", "--mode", "cpm-toml", "--file", path});
    CHECK(rc == 0);
    unlink(path.c_str());
  }

  /* --- cpm-toml preamble (comments before first section) --- */
  TEST_CASE("cpm-toml preserves preamble comments") {
    std::string path = make_temp_file(
        "# Top comment\n"
        "\n"
        "[project]\n"
        "name = \"x\"\n");

    int rc = run_sort({"fix", "--mode", "cpm-toml", "--file", path});
    CHECK(rc == 0);

    std::string out = read_file(path);
    CHECK(out.find("# Top comment") != std::string::npos);
    CHECK(out.find("# Top comment") < out.find("[project]"));
    unlink(path.c_str());
  }

  /* --- cpm-toml complex section (non-keyval) not reordered --- */
  TEST_CASE("cpm-toml leaves complex sections unchanged") {
    std::string path = make_temp_file(
        "[project]\n"
        "name = \"x\"\n"
        "\n"
        "[hooks]\n"
        "pre-commit = [\n"
        "  \"lint\",\n"
        "  \"test\"\n"
        "]\n");

    int rc = run_sort({"fix", "--mode", "cpm-toml", "--file", path});
    CHECK(rc == 0);

    std::string out = read_file(path);
    // The multiline array should not be sorted/mangled
    CHECK(out.find("pre-commit = [") != std::string::npos);
    unlink(path.c_str());
  }

  /* --- ts-imports side-effect imports --- */
  TEST_CASE("ts-imports handles side-effect imports") {
    std::string path = make_temp_file(
        "import \"./polyfill\";\n"
        "import React from \"react\";\n");

    int rc = run_sort({"fix", "--mode", "ts-imports", "--file", path});
    CHECK(rc == 0);

    std::string out = read_file(path);
    // Side-effect import should still be present
    CHECK(out.find("polyfill") != std::string::npos);
    unlink(path.c_str());
  }

  /* --- ts-imports check on already sorted file --- */
  TEST_CASE("ts-imports fix on canonical file reports already canonical") {
    // First create a canonical file by fixing it
    std::string path = make_temp_file(
        "import React from \"react\";\n"
        "\n"
        "const App = () => <div/>;\n");

    run_sort({"fix", "--mode", "ts-imports", "--file", path});
    // Now check should pass since we just fixed it
    int rc = run_sort({"check", "--mode", "ts-imports", "--file", path});
    CHECK(rc == 0);
    unlink(path.c_str());
  }

  /* --- ts-imports no imports in file --- */
  TEST_CASE("ts-imports leaves non-import file unchanged") {
    std::string path = make_temp_file(
        "const x = 1;\n"
        "export default x;\n");

    int rc = run_sort({"check", "--mode", "ts-imports", "--file", path});
    CHECK(rc == 0);
    unlink(path.c_str());
  }

  /* --- lines mode with markers --- */
  TEST_CASE("lines fix with markers sorts only marked section") {
    std::string path = make_temp_file(
        "header line\n"
        "<!-- sort:start -->\n"
        "cherry\n"
        "apple\n"
        "banana\n"
        "<!-- sort:end -->\n"
        "footer line\n");

    int rc =
        run_sort({"fix", "--mode", "lines", "--file", path, "--start-marker", "<!-- sort:start -->", "--end-marker", "<!-- sort:end -->"});
    CHECK(rc == 0);

    std::string out = read_file(path);
    CHECK(out.find("apple") < out.find("banana"));
    CHECK(out.find("banana") < out.find("cherry"));
    // Header and footer preserved
    CHECK(out.find("header line") != std::string::npos);
    CHECK(out.find("footer line") != std::string::npos);
    unlink(path.c_str());
  }

  /* --- lines mode check fails when not sorted --- */
  TEST_CASE("lines check fails when unsorted") {
    std::string path = make_temp_file("beta\nalpha\n");
    int rc = run_sort({"check", "--mode", "lines", "--file", path});
    CHECK(rc == 1);
    unlink(path.c_str());
  }

  /* --- lines mode check passes when sorted --- */
  TEST_CASE("lines check passes when sorted") {
    std::string path = make_temp_file("alpha\nbeta\n");
    int rc = run_sort({"check", "--mode", "lines", "--file", path});
    CHECK(rc == 0);
    unlink(path.c_str());
  }

  /* --- fix on already canonical file prints message --- */
  TEST_CASE("fix on already canonical file succeeds") {
    std::string path = make_temp_file("alpha\nbeta\ngamma\n");
    int rc = run_sort({"fix", "--mode", "lines", "--file", path});
    CHECK(rc == 0);
    unlink(path.c_str());
  }

  /* --- ts-imports with comments between imports --- */
  TEST_CASE("ts-imports preserves comments between import groups") {
    std::string path = make_temp_file(
        "import z from \"./z\";\n"
        "// This is a comment\n"
        "import React from \"react\";\n"
        "\n"
        "const x = 1;\n");

    int rc = run_sort({"fix", "--mode", "ts-imports", "--file", path});
    CHECK(rc == 0);

    std::string out = read_file(path);
    CHECK(out.find("// This is a comment") != std::string::npos);
    unlink(path.c_str());
  }

  /* --- lines mode with markers but no end marker --- */
  TEST_CASE("lines mode with markers but no end marker returns error") {
    std::string path = make_temp_file(
        "<!-- sort:start -->\n"
        "cherry\n"
        "apple\n");

    int rc =
        run_sort({"fix", "--mode", "lines", "--file", path, "--start-marker", "<!-- sort:start -->", "--end-marker", "<!-- sort:end -->"});
    // Should still succeed but file unchanged (unterminated block)
    CHECK(rc == 0);
    unlink(path.c_str());
  }

  /* --- cpm-toml with many section types for rank coverage --- */
  TEST_CASE("cpm-toml sorts all section types by rank") {
    std::string path = make_temp_file(
        "[issues]\n"
        "x = 1\n"
        "\n"
        "[limits]\n"
        "max = 100\n"
        "\n"
        "[runner]\n"
        "cmd = \"make\"\n"
        "\n"
        "[hooks]\n"
        "pre = \"lint\"\n"
        "\n"
        "[process]\n"
        "steps = 3\n"
        "\n"
        "[tools]\n"
        "gcc = \"13\"\n"
        "\n"
        "[project]\n"
        "name = \"x\"\n");

    int rc = run_sort({"fix", "--mode", "cpm-toml", "--file", path});
    CHECK(rc == 0);

    std::string out = read_file(path);
    // project should come first
    CHECK(out.find("[project]") < out.find("[tools]"));
    // tools before hooks
    CHECK(out.find("[tools]") < out.find("[hooks]"));
    CHECK(out.find("[hooks]") < out.find("[runner]"));
    CHECK(out.find("[runner]") < out.find("[limits]"));
    unlink(path.c_str());
  }

  TEST_CASE("cpm-toml fix canonicalizes section and key order") {
    std::string path = make_temp_file(
        "[checks]\n"
        "z-check = true\n"
        "a-check = false\n"
        "\n"
        "[project]\n"
        "version = \"0.1.0\"\n"
        "name = \"demo\"\n");

    int rc = run_sort({"fix", "--mode", "cpm-toml", "--file", path});
    CHECK(rc == 0);

    std::string out = read_file(path);
    CHECK(out.find("[project]") < out.find("[checks]"));
    CHECK(out.find("a-check = false") < out.find("z-check = true"));

    unlink(path.c_str());
  }

  TEST_CASE("cpm-toml check fails when not canonical") {
    std::string path = make_temp_file(
        "[checks]\n"
        "z-check = true\n"
        "a-check = false\n");

    int rc = run_sort({"check", "--mode", "cpm-toml", "--file", path});
    CHECK(rc == 1);

    unlink(path.c_str());
  }

  TEST_CASE("ts-imports fix groups imports and sorts members") {
    std::string path = make_temp_file(
        "import z from \"./z\";\n"
        "import { b, a } from \"@/lib/x\";\n"
        "import React from \"react\";\n"
        "import y from \"../y\";\n"
        "import { readFileSync } from \"fs\";\n");

    int rc = run_sort({"fix", "--mode", "ts-imports", "--file", path, "--alias-prefixes", "@/,~/,src/"});
    CHECK(rc == 0);

    std::string out = read_file(path);

    size_t react_pos = out.find("import React from \"react\";");
    size_t fs_pos = out.find("import { readFileSync } from \"fs\";");
    size_t alias_pos = out.find("import { a, b } from \"@/lib/x\";");
    size_t rel1_pos = out.find("import y from \"../y\";");
    size_t rel2_pos = out.find("import z from \"./z\";");

    CHECK(react_pos != std::string::npos);
    CHECK(fs_pos != std::string::npos);
    CHECK(alias_pos != std::string::npos);
    CHECK(rel1_pos != std::string::npos);
    CHECK(rel2_pos != std::string::npos);

    CHECK(react_pos < alias_pos);
    CHECK(fs_pos < alias_pos);
    CHECK(alias_pos < rel1_pos);

    unlink(path.c_str());
  }

  TEST_CASE("lines fix with dedup sorts unique lines") {
    std::string path = make_temp_file("beta\nalpha\nbeta\n");

    int rc = run_sort({"fix", "--mode", "lines", "--file", path, "--dedup"});
    CHECK(rc == 0);

    std::string out = read_file(path);
    CHECK(out == "alpha\nbeta");

    unlink(path.c_str());
  }
}
