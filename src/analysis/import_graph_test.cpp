/**
 * @file import_graph_test.cpp
 * @brief Unit tests for import graph — extraction, cycle detection, dead modules, metrics.
 * @see ADR-130 for test architecture (TEST_SUITE + SCENARIO/GIVEN/WHEN/THEN)
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "import_graph.h"

#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#include <algorithm>
#include <cstdlib>
#include <fstream>

#include "../../vendor/doctest.h"

/* ── Test helpers (same pattern as rules_test.cpp) ──────────── */

static std::string create_temp_dir() {
  char template_path[] = "/tmp/cpm_import_graph_test_XXXXXX";
  char* dir = mkdtemp(template_path);
  return dir ? std::string(dir) : "";
}

static void write_file(const std::string& path, const std::string& content) {
  /* Create parent directories if needed */
  size_t pos = 0;
  while ((pos = path.find('/', pos + 1)) != std::string::npos) {
    std::string dir = path.substr(0, pos);
    mkdir(dir.c_str(), 0755);
  }
  std::ofstream out(path);
  out << content;
}

static void remove_recursive(const std::string& path) {
  DIR* d = opendir(path.c_str());
  if (!d) {
    unlink(path.c_str());
    return;
  }
  struct dirent* entry;
  while ((entry = readdir(d)) != nullptr) {
    std::string name = entry->d_name;
    if (name == "." || name == "..") continue;
    std::string full = path + "/" + name;
    struct stat st;
    if (stat(full.c_str(), &st) == 0 && S_ISDIR(st.st_mode))
      remove_recursive(full);
    else
      unlink(full.c_str());
  }
  closedir(d);
  rmdir(path.c_str());
}

/* ── Helper: check if a finding of a given type exists ──────── */

static bool has_finding(const std::vector<GraphFinding>& findings, const std::string& type, const std::string& file = "") {
  for (const auto& f : findings) {
    if (f.type == type && (file.empty() || f.file == file)) return true;
  }
  return false;
}

static int count_findings(const std::vector<GraphFinding>& findings, const std::string& type) {
  int count = 0;
  for (const auto& f : findings) {
    if (f.type == type) ++count;
  }
  return count;
}

TEST_SUITE("import-graph") {
  // ============================================================
  // Import extraction tests
  // ============================================================

  SCENARIO("JS/TS import extraction") {
    GIVEN("a TypeScript file with various import styles") {
      std::string content =
          "import { foo } from './foo';\n"
          "import bar from '../bar';\n"
          "const baz = require('./baz');\n"
          "const lazy = import('./lazy');\n"
          "import React from 'react';\n"
          "export { util } from './util';\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".ts");

        THEN("all import targets are found") {
          REQUIRE(imports.size() == 6);
          CHECK(std::find(imports.begin(), imports.end(), "./foo") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "../bar") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "./baz") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "./lazy") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "react") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "./util") != imports.end());
        }
      }
    }

    GIVEN("a JS file with require calls") {
      std::string content =
          "const express = require('express');\n"
          "const path = require('path');\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".js");

        THEN("require targets are found") {
          REQUIRE(imports.size() == 2);
          CHECK(std::find(imports.begin(), imports.end(), "express") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "path") != imports.end());
        }
      }
    }
  }

  SCENARIO("Python import extraction") {
    GIVEN("a Python file with from/import statements") {
      std::string content =
          "from os.path import join\n"
          "from flask import Flask\n"
          "import sys\n"
          "import json\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".py");

        THEN("all module names are found") {
          REQUIRE(imports.size() == 4);
          CHECK(std::find(imports.begin(), imports.end(), "os.path") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "flask") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "sys") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "json") != imports.end());
        }
      }
    }
  }

  SCENARIO("Go import extraction") {
    GIVEN("a Go file with single and block imports") {
      std::string content =
          "package main\n"
          "\n"
          "import \"fmt\"\n"
          "\n"
          "import (\n"
          "  \"os\"\n"
          "  \"net/http\"\n"
          ")\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".go");

        THEN("all packages are found") {
          REQUIRE(imports.size() == 3);
          CHECK(std::find(imports.begin(), imports.end(), "fmt") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "os") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "net/http") != imports.end());
        }
      }
    }
  }

  SCENARIO("Java import extraction") {
    GIVEN("a Java file with package imports") {
      std::string content =
          "package com.example;\n"
          "\n"
          "import java.util.List;\n"
          "import java.io.File;\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".java");

        THEN("fully qualified names are found") {
          REQUIRE(imports.size() == 2);
          CHECK(std::find(imports.begin(), imports.end(), "java.util.List") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "java.io.File") != imports.end());
        }
      }
    }
  }

  SCENARIO("C/C++ include extraction") {
    GIVEN("a C++ file with user and system includes") {
      std::string content =
          "#include <iostream>\n"
          "#include <vector>\n"
          "#include \"my_header.h\"\n"
          "#include \"utils/helper.h\"\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".cpp");

        THEN("only user includes are extracted (not system)") {
          REQUIRE(imports.size() == 2);
          CHECK(std::find(imports.begin(), imports.end(), "my_header.h") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "utils/helper.h") != imports.end());
        }
      }
    }
  }

  SCENARIO("C# using extraction") {
    GIVEN("a C# file with using statements") {
      std::string content =
          "using System;\n"
          "using System.Collections.Generic;\n"
          "using MyApp.Services;\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".cs");

        THEN("namespace references are found") {
          REQUIRE(imports.size() == 3);
          CHECK(std::find(imports.begin(), imports.end(), "System") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "System.Collections.Generic") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "MyApp.Services") != imports.end());
        }
      }
    }
  }

  SCENARIO("PHP import extraction") {
    GIVEN("a PHP file with use and require_once") {
      std::string content =
          "<?php\n"
          "use App\\Models\\User;\n"
          "use App\\Services\\Auth;\n"
          "require_once 'vendor/autoload.php';\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".php");

        THEN("all imports are found") {
          REQUIRE(imports.size() == 3);
          CHECK(std::find(imports.begin(), imports.end(), "App\\Models\\User") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "App\\Services\\Auth") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "vendor/autoload.php") != imports.end());
        }
      }
    }
  }

  SCENARIO("Ruby import extraction") {
    GIVEN("a Ruby file with require and require_relative") {
      std::string content =
          "require 'json'\n"
          "require_relative 'helpers/parser'\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".rb");

        THEN("both types are found") {
          REQUIRE(imports.size() == 2);
          CHECK(std::find(imports.begin(), imports.end(), "json") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "helpers/parser") != imports.end());
        }
      }
    }
  }

  SCENARIO("Rust import extraction") {
    GIVEN("a Rust file with use and mod statements") {
      std::string content =
          "use crate::utils::helper;\n"
          "use crate::config;\n"
          "mod parser;\n"
          "mod lexer;\n";

      WHEN("imports are extracted") {
        auto imports = extract_imports(content, ".rs");

        THEN("all imports are found") {
          REQUIRE(imports.size() == 4);
          CHECK(std::find(imports.begin(), imports.end(), "crate::utils::helper") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "crate::config") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "parser") != imports.end());
          CHECK(std::find(imports.begin(), imports.end(), "lexer") != imports.end());
        }
      }
    }
  }

  SCENARIO("unknown extension returns empty") {
    GIVEN("content with an unsupported extension") {
      WHEN("imports are extracted") {
        auto imports = extract_imports("random content", ".xyz");
        THEN("no imports are returned") { CHECK(imports.empty()); }
      }
    }
  }

  // ============================================================
  // Cycle detection tests
  // ============================================================

  SCENARIO("cycle detection: A→B→C→A") {
    GIVEN("three TS files forming a cycle") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      write_file(tmp + "/a.ts", "import { b } from './b';\nexport const a = 1;\n");
      write_file(tmp + "/b.ts", "import { c } from './c';\nexport const b = 2;\n");
      write_file(tmp + "/c.ts", "import { a } from './a';\nexport const c = 3;\n");

      WHEN("the graph is built and analyzed") {
        auto graph = build_import_graph(tmp);
        auto findings = analyze_graph(graph);

        THEN("a cycle is detected") {
          CHECK(count_findings(findings, "cycle") >= 1);
          /* All three files should be in the cycle */
          CHECK(has_finding(findings, "cycle", "a.ts"));
          CHECK(has_finding(findings, "cycle", "b.ts"));
          CHECK(has_finding(findings, "cycle", "c.ts"));
        }
      }
      remove_recursive(tmp);
    }
  }

  SCENARIO("no cycle in DAG") {
    GIVEN("three TS files with no cycle (A→B→C)") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      write_file(tmp + "/a.ts", "import { b } from './b';\n");
      write_file(tmp + "/b.ts", "import { c } from './c';\n");
      write_file(tmp + "/c.ts", "export const c = 3;\n");

      WHEN("the graph is analyzed") {
        auto graph = build_import_graph(tmp);
        auto findings = analyze_graph(graph);

        THEN("no cycles are found") { CHECK(count_findings(findings, "cycle") == 0); }
      }
      remove_recursive(tmp);
    }
  }

  // ============================================================
  // Dead module detection tests
  // ============================================================

  SCENARIO("dead module detection") {
    GIVEN("files where orphan.ts is never imported") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      /* main.ts imports util.ts — both are entry/used */
      write_file(tmp + "/main.ts", "import { util } from './util';\n");
      write_file(tmp + "/util.ts", "export const util = 1;\n");
      /* orphan.ts is never imported and not an entry point */
      write_file(tmp + "/orphan.ts", "export const orphan = 42;\n");

      WHEN("the graph is analyzed") {
        auto graph = build_import_graph(tmp);
        auto findings = analyze_graph(graph);

        THEN("orphan.ts is flagged as dead module") { CHECK(has_finding(findings, "dead-module", "orphan.ts")); }
        THEN("main.ts is NOT flagged (entry point)") { CHECK(!has_finding(findings, "dead-module", "main.ts")); }
      }
      remove_recursive(tmp);
    }
  }

  SCENARIO("test files are not flagged as dead modules") {
    GIVEN("a test file with zero importers") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      write_file(tmp + "/parser.ts", "export function parse() {}\n");
      write_file(tmp + "/parser.test.ts", "import { parse } from './parser';\n");

      WHEN("the graph is analyzed") {
        auto graph = build_import_graph(tmp);
        auto findings = analyze_graph(graph);

        THEN("the test file is not flagged") { CHECK(!has_finding(findings, "dead-module", "parser.test.ts")); }
      }
      remove_recursive(tmp);
    }
  }

  // ============================================================
  // Fan-in / fan-out counting tests
  // ============================================================

  SCENARIO("fan-in and fan-out counting") {
    GIVEN("a hub-and-spoke topology: hub imports A, B, C") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      write_file(tmp + "/hub.ts",
                 "import { a } from './a';\n"
                 "import { b } from './b';\n"
                 "import { c } from './c';\n");
      write_file(tmp + "/a.ts", "export const a = 1;\n");
      write_file(tmp + "/b.ts", "export const b = 2;\n");
      write_file(tmp + "/c.ts", "export const c = 3;\n");

      WHEN("the graph is built") {
        auto graph = build_import_graph(tmp);

        THEN("hub has fan_out == 3") { CHECK(graph.fan_out["hub.ts"] == 3); }
        THEN("hub has fan_in == 0") { CHECK(graph.fan_in["hub.ts"] == 0); }
      }
      remove_recursive(tmp);
    }
  }

  SCENARIO("C++ include fan-in counting") {
    GIVEN("multiple cpp files including the same header") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      write_file(tmp + "/common.h", "// shared header\n");
      write_file(tmp + "/a.cpp", "#include \"common.h\"\n");
      write_file(tmp + "/b.cpp", "#include \"common.h\"\n");
      write_file(tmp + "/c.cpp", "#include \"common.h\"\n");

      WHEN("the graph is built") {
        auto graph = build_import_graph(tmp);

        THEN("common.h has fan_in == 3") { CHECK(graph.fan_in["common.h"] == 3); }
        THEN("each .cpp has fan_out == 1") {
          CHECK(graph.fan_out["a.cpp"] == 1);
          CHECK(graph.fan_out["b.cpp"] == 1);
          CHECK(graph.fan_out["c.cpp"] == 1);
        }
      }
      remove_recursive(tmp);
    }
  }

  // ============================================================
  // High fan-out detection
  // ============================================================

  SCENARIO("high fan-out detection") {
    GIVEN("a file importing more than 15 modules") {
      /* Construct graph directly — no need for real files */
      ImportGraph graph;
      std::string god = "god_module.ts";
      graph.files.push_back(god);
      graph.fan_out[god] = 16;
      graph.fan_in[god] = 0;

      /* Add 16 dummy targets */
      for (int i = 0; i < 16; ++i) {
        std::string dep = "dep_" + std::to_string(i) + ".ts";
        graph.files.push_back(dep);
        graph.adjacency[god].push_back(dep);
        graph.fan_in[dep] = 1;
        graph.fan_out[dep] = 0;
      }

      WHEN("the graph is analyzed") {
        auto findings = analyze_graph(graph);

        THEN("the god module is flagged for high fan-out") { CHECK(has_finding(findings, "high-fan-out", god)); }
      }
    }
  }

  // ============================================================
  // High fan-in detection
  // ============================================================

  SCENARIO("high fan-in detection") {
    GIVEN("a file imported by more than 20 files") {
      ImportGraph graph;
      std::string core = "core.ts";
      graph.files.push_back(core);
      graph.fan_in[core] = 21;
      graph.fan_out[core] = 0;

      for (int i = 0; i < 21; ++i) {
        std::string consumer = "consumer_" + std::to_string(i) + ".ts";
        graph.files.push_back(consumer);
        graph.adjacency[consumer].push_back(core);
        graph.fan_in[consumer] = 0;
        graph.fan_out[consumer] = 1;
      }

      WHEN("the graph is analyzed") {
        auto findings = analyze_graph(graph);

        THEN("the core module is flagged for high fan-in") { CHECK(has_finding(findings, "high-fan-in", core)); }
      }
    }
  }

  // ============================================================
  // build_import_graph integration test
  // ============================================================

  SCENARIO("build_import_graph with subdirectories") {
    GIVEN("a project with nested source files") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      write_file(tmp + "/src/server.ts",
                 "import { db } from './db';\n"
                 "import { auth } from './middleware/auth';\n");
      write_file(tmp + "/src/db.ts", "export const db = {};\n");
      write_file(tmp + "/src/middleware/auth.ts",
                 "import { db } from '../db';\n"
                 "export const auth = {};\n");

      WHEN("the graph is built from root") {
        auto graph = build_import_graph(tmp);

        THEN("all source files are discovered") { REQUIRE(graph.files.size() == 3); }
        THEN("adjacency is populated") {
          /* server.ts imports 2 modules */
          bool found_server = false;
          for (const auto& [file, deps] : graph.adjacency) {
            if (file.find("server.ts") != std::string::npos) {
              CHECK(deps.size() == 2);
              found_server = true;
            }
          }
          CHECK(found_server);
        }
      }
      remove_recursive(tmp);
    }
  }

  SCENARIO("node_modules and .git are skipped") {
    GIVEN("a project with vendor directories") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      write_file(tmp + "/src/app.ts", "import { foo } from 'foo';\n");
      write_file(tmp + "/node_modules/foo/index.js", "module.exports = {};\n");
      write_file(tmp + "/.git/config", "# git config\n");

      WHEN("the graph is built") {
        auto graph = build_import_graph(tmp);

        THEN("only source files are included (not node_modules or .git)") {
          REQUIRE(graph.files.size() == 1);
          CHECK(graph.files[0].find("app.ts") != std::string::npos);
        }
      }
      remove_recursive(tmp);
    }
  }

  // ============================================================
  // Empty / edge cases
  // ============================================================

  SCENARIO("empty graph produces no findings") {
    GIVEN("an empty import graph") {
      ImportGraph graph;

      WHEN("the graph is analyzed") {
        auto findings = analyze_graph(graph);
        THEN("no findings are produced") { CHECK(findings.empty()); }
      }
    }
  }

  SCENARIO("empty directory produces empty graph") {
    GIVEN("an empty temp directory") {
      std::string tmp = create_temp_dir();
      REQUIRE(!tmp.empty());

      WHEN("the graph is built") {
        auto graph = build_import_graph(tmp);

        THEN("graph is empty") {
          CHECK(graph.files.empty());
          CHECK(graph.adjacency.empty());
        }
      }
      remove_recursive(tmp);
    }
  }

}  // TEST_SUITE("import-graph")
