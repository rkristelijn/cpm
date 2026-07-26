#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN

#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

#include "commands/commands.h"
#include "../vendor/doctest.h"

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
