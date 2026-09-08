/**
 * @file tokenizer_test.cpp
 * @brief Unit tests for the language-aware tokenizer.
 * @see ADR-130 for test architecture (TEST_SUITE + SCENARIO/GIVEN/WHEN/THEN)
 *
 * Tests cover:
 * - Extension lookup (known + unknown)
 * - C-style // and block comment stripping
 * - Python # comments
 * - String literal stripping (double, single, backtick)
 * - Escaped quotes inside strings
 * - Triple-quoted Python strings
 * - Mixed comments and strings
 * - Line count preservation
 * - Edge cases (empty input, nullptr syntax)
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN

#include "tokenizer.h"

#include "../../vendor/doctest.h"

// --- Helper: count newlines in a string ---
static int count_lines(const std::string& s) {
  int lines = 1;
  for (char c : s) {
    if (c == '\n') lines++;
  }
  return lines;
}

TEST_SUITE("tokenizer") {
  // ============================================================
  // Extension lookup
  // ============================================================

  SCENARIO("extension lookup") {
    GIVEN("known C++ extensions") {
      THEN(".cpp returns a syntax entry") {
        auto* s = lang_syntax(".cpp");
        REQUIRE(s != nullptr);
        CHECK(std::string(s->line_comment) == "//");
        CHECK(std::string(s->block_start) == "/*");
        CHECK(std::string(s->block_end) == "*/");
      }
      THEN(".h returns a syntax entry") { CHECK(lang_syntax(".h") != nullptr); }
      THEN(".java returns a syntax entry") { CHECK(lang_syntax(".java") != nullptr); }
    }

    GIVEN("known scripting extensions") {
      THEN(".py returns Python syntax") {
        auto* s = lang_syntax(".py");
        REQUIRE(s != nullptr);
        CHECK(std::string(s->line_comment) == "#");
        CHECK(s->block_start == nullptr);
        CHECK(s->triple_strings == true);
      }
      THEN(".sh returns shell syntax") {
        auto* s = lang_syntax(".sh");
        REQUIRE(s != nullptr);
        CHECK(std::string(s->line_comment) == "#");
      }
      THEN(".rb returns Ruby syntax") {
        auto* s = lang_syntax(".rb");
        REQUIRE(s != nullptr);
        CHECK(std::string(s->line_comment) == "#");
        CHECK(std::string(s->block_start) == "=begin");
      }
    }

    GIVEN("known web extensions") {
      THEN(".js returns JS syntax with backtick support") {
        auto* s = lang_syntax(".js");
        REQUIRE(s != nullptr);
        CHECK(s->string_delims[2] == '`');
      }
      THEN(".html returns HTML syntax") {
        auto* s = lang_syntax(".html");
        REQUIRE(s != nullptr);
        CHECK(std::string(s->block_start) == "<!--");
        CHECK(std::string(s->block_end) == "-->");
        CHECK(s->line_comment == nullptr);
      }
      THEN(".css returns CSS syntax") {
        auto* s = lang_syntax(".css");
        REQUIRE(s != nullptr);
        CHECK(std::string(s->block_start) == "/*");
        CHECK(s->line_comment == nullptr);
      }
    }

    GIVEN("config file extensions") {
      THEN(".yml returns YAML syntax") { CHECK(lang_syntax(".yml") != nullptr); }
      THEN(".toml returns TOML syntax") { CHECK(lang_syntax(".toml") != nullptr); }
      THEN(".tf returns Terraform syntax") {
        auto* s = lang_syntax(".tf");
        REQUIRE(s != nullptr);
        CHECK(std::string(s->line_comment) == "#");
        CHECK(std::string(s->block_start) == "/*");
      }
    }

    GIVEN("an unknown extension") {
      THEN("returns nullptr") {
        CHECK(lang_syntax(".xyz") == nullptr);
        CHECK(lang_syntax(".zzz") == nullptr);
        CHECK(lang_syntax("") == nullptr);
      }
    }

    GIVEN("markdown extension") {
      THEN("returns a syntax entry with no comment markers") {
        auto* s = lang_syntax(".md");
        REQUIRE(s != nullptr);
        CHECK(s->line_comment == nullptr);
        CHECK(s->block_start == nullptr);
      }
    }
  }

  // ============================================================
  // C-style line comments (//)
  // ============================================================

  SCENARIO("C-style line comment stripping") {
    auto* syntax = lang_syntax(".cpp");
    REQUIRE(syntax != nullptr);

    GIVEN("code with a line comment") {
      std::string input = "int x = 1; // initialize x\nint y = 2;\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("the comment is replaced with spaces") {
          CHECK(result.find("//") == std::string::npos);
          CHECK(result.find("initialize") == std::string::npos);
        }
        THEN("the code is preserved") {
          CHECK(result.find("int x = 1;") != std::string::npos);
          CHECK(result.find("int y = 2;") != std::string::npos);
        }
      }
    }

    GIVEN("a line that is entirely a comment") {
      std::string input = "// this is a comment\nint x;\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("the comment line becomes spaces") {
          // First line should be all spaces before the newline
          CHECK(result.find("//") == std::string::npos);
          CHECK(result.find("int x;") != std::string::npos);
        }
      }
    }
  }

  // ============================================================
  // C-style block comments (/* */)
  // ============================================================

  SCENARIO("C-style block comment stripping") {
    auto* syntax = lang_syntax(".cpp");
    REQUIRE(syntax != nullptr);

    GIVEN("code with an inline block comment") {
      std::string input = "int x = /* value */ 42;\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("the block comment is blanked") {
          CHECK(result.find("/*") == std::string::npos);
          CHECK(result.find("value") == std::string::npos);
          CHECK(result.find("42") != std::string::npos);
        }
      }
    }

    GIVEN("a multi-line block comment") {
      std::string input = "before\n/* line 1\n   line 2\n   line 3 */\nafter\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("all comment content is blanked") {
          CHECK(result.find("/*") == std::string::npos);
          CHECK(result.find("line 1") == std::string::npos);
        }
        THEN("surrounding code is preserved") {
          CHECK(result.find("before") != std::string::npos);
          CHECK(result.find("after") != std::string::npos);
        }
        THEN("line count is preserved") { CHECK(count_lines(result) == count_lines(input)); }
      }
    }
  }

  // ============================================================
  // Python # comments
  // ============================================================

  SCENARIO("Python hash comment stripping") {
    auto* syntax = lang_syntax(".py");
    REQUIRE(syntax != nullptr);

    GIVEN("Python code with # comments") {
      std::string input = "x = 1  # set x\ny = 2\n# full line comment\nz = 3\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("hash comments are removed") {
          CHECK(result.find("#") == std::string::npos);
          CHECK(result.find("set x") == std::string::npos);
          CHECK(result.find("full line comment") == std::string::npos);
        }
        THEN("code is preserved") {
          CHECK(result.find("x = 1") != std::string::npos);
          CHECK(result.find("y = 2") != std::string::npos);
          CHECK(result.find("z = 3") != std::string::npos);
        }
      }
    }
  }

  // ============================================================
  // String literal stripping
  // ============================================================

  SCENARIO("string literal stripping") {
    auto* syntax = lang_syntax(".cpp");
    REQUIRE(syntax != nullptr);

    GIVEN("code with double-quoted strings") {
      std::string input = "printf(\"hello world\");\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, syntax);

        THEN("string content is blanked") { CHECK(result.find("hello world") == std::string::npos); }
        THEN("code structure is preserved") {
          CHECK(result.find("printf(") != std::string::npos);
          CHECK(result.find(");") != std::string::npos);
        }
      }

      WHEN("only comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("string content is preserved") { CHECK(result.find("hello world") != std::string::npos); }
      }
    }

    GIVEN("code with single-quoted strings") {
      std::string input = "char c = 'x';\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, syntax);

        THEN("char literal is blanked") { CHECK(result.find("'x'") == std::string::npos); }
      }
    }

    GIVEN("JavaScript with backtick template literals") {
      auto* js = lang_syntax(".js");
      REQUIRE(js != nullptr);
      std::string input = "const s = `hello ${name}`;\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, js);

        THEN("template literal content is blanked") {
          CHECK(result.find("hello") == std::string::npos);
          CHECK(result.find("${name}") == std::string::npos);
        }
      }
    }
  }

  // ============================================================
  // Escaped quotes inside strings
  // ============================================================

  SCENARIO("escaped quotes inside strings") {
    auto* syntax = lang_syntax(".cpp");
    REQUIRE(syntax != nullptr);

    GIVEN("a string with escaped double quotes") {
      std::string input = "char* s = \"say \\\"hello\\\"\";\nint x;\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, syntax);

        THEN("the entire string including escaped quotes is blanked") {
          CHECK(result.find("say") == std::string::npos);
          CHECK(result.find("hello") == std::string::npos);
        }
        THEN("code after the string is preserved") { CHECK(result.find("int x;") != std::string::npos); }
      }
    }

    GIVEN("a string with an escaped backslash before the closing quote") {
      std::string input = "s = \"path\\\\\";\nint y;\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, syntax);

        THEN("the string is correctly terminated") { CHECK(result.find("int y;") != std::string::npos); }
      }
    }
  }

  // ============================================================
  // Triple-quoted Python strings
  // ============================================================

  SCENARIO("triple-quoted Python strings") {
    auto* syntax = lang_syntax(".py");
    REQUIRE(syntax != nullptr);

    GIVEN("a triple-double-quoted docstring") {
      std::string input = "def foo():\n    \"\"\"This is a docstring.\n    Multi-line.\"\"\"\n    pass\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, syntax);

        THEN("docstring content is blanked") {
          CHECK(result.find("This is a docstring") == std::string::npos);
          CHECK(result.find("Multi-line") == std::string::npos);
        }
        THEN("code is preserved") {
          CHECK(result.find("def foo():") != std::string::npos);
          CHECK(result.find("pass") != std::string::npos);
        }
        THEN("line count is preserved") { CHECK(count_lines(result) == count_lines(input)); }
      }
    }

    GIVEN("a triple-single-quoted string") {
      std::string input = "x = '''multi\nline'''\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, syntax);

        THEN("triple-single-quoted content is blanked") {
          CHECK(result.find("multi") == std::string::npos);
          CHECK(result.find("line") == std::string::npos);
        }
      }
    }
  }

  // ============================================================
  // Mixed comments and strings
  // ============================================================

  SCENARIO("mixed comments and strings") {
    auto* syntax = lang_syntax(".cpp");
    REQUIRE(syntax != nullptr);

    GIVEN("a comment marker inside a string") {
      std::string input = "char* s = \"// not a comment\";\nint x = 1;\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("the // inside the string is NOT stripped") {
          // The string protects its content from being treated as a comment
          CHECK(result.find("int x = 1;") != std::string::npos);
        }
      }
    }

    GIVEN("a string delimiter inside a comment") {
      std::string input = "// this has a \" quote\nint x;\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("the quote inside the comment doesn't start a string") {
          CHECK(result.find("int x;") != std::string::npos);
          CHECK(result.find("this has") == std::string::npos);
        }
      }
    }

    GIVEN("code with both comments and strings") {
      std::string input = "printf(\"hello\"); // greeting\nint y = /* val */ 5;\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, syntax);

        THEN("both are blanked") {
          CHECK(result.find("hello") == std::string::npos);
          CHECK(result.find("greeting") == std::string::npos);
          CHECK(result.find("val") == std::string::npos);
        }
        THEN("code structure remains") {
          CHECK(result.find("printf(") != std::string::npos);
          CHECK(result.find("5;") != std::string::npos);
        }
      }
    }
  }

  // ============================================================
  // Edge cases
  // ============================================================

  SCENARIO("edge cases") {
    GIVEN("nullptr syntax") {
      std::string input = "some code // comment\n";

      WHEN("strip_comments is called with nullptr") {
        std::string result = strip_comments(input, nullptr);

        THEN("content is returned unchanged") { CHECK(result == input); }
      }

      WHEN("strip_comments_and_strings is called with nullptr") {
        std::string result = strip_comments_and_strings(input, nullptr);

        THEN("content is returned unchanged") { CHECK(result == input); }
      }
    }

    GIVEN("empty input") {
      auto* syntax = lang_syntax(".cpp");
      std::string input;

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("result is empty") { CHECK(result.empty()); }
      }
    }

    GIVEN("input with no comments or strings") {
      auto* syntax = lang_syntax(".cpp");
      std::string input = "int x = 1;\nint y = 2;\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("content is unchanged") { CHECK(result == input); }
      }
    }
  }

  // ============================================================
  // Line count preservation
  // ============================================================

  SCENARIO("line count preservation") {
    GIVEN("C++ code with multi-line block comment") {
      auto* syntax = lang_syntax(".cpp");
      std::string input =
          "line1\n"
          "/* comment\n"
          "   still comment\n"
          "   end */\n"
          "line5\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("line count matches") { CHECK(count_lines(result) == count_lines(input)); }
      }
    }

    GIVEN("Python code with triple-quoted string spanning lines") {
      auto* syntax = lang_syntax(".py");
      std::string input =
          "x = 1\n"
          "s = \"\"\"line1\n"
          "line2\n"
          "line3\"\"\"\n"
          "y = 2\n";

      WHEN("comments and strings are stripped") {
        std::string result = strip_comments_and_strings(input, syntax);

        THEN("line count matches") { CHECK(count_lines(result) == count_lines(input)); }
      }
    }

    GIVEN("many lines with mixed comments") {
      auto* syntax = lang_syntax(".py");
      std::string input;
      for (int i = 0; i < 100; i++) {
        input += "code_" + std::to_string(i) + "  # comment " + std::to_string(i) + "\n";
      }

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("all 100 lines are preserved") { CHECK(count_lines(result) == count_lines(input)); }
      }
    }
  }

  // ============================================================
  // HTML / XML block comments
  // ============================================================

  SCENARIO("HTML block comment stripping") {
    auto* syntax = lang_syntax(".html");
    REQUIRE(syntax != nullptr);

    GIVEN("HTML with a comment") {
      std::string input = "<div><!-- hidden --></div>\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("comment content is blanked") {
          CHECK(result.find("<!--") == std::string::npos);
          CHECK(result.find("hidden") == std::string::npos);
        }
        THEN("tags are preserved") {
          CHECK(result.find("<div>") != std::string::npos);
          CHECK(result.find("</div>") != std::string::npos);
        }
      }
    }
  }

  // ============================================================
  // SQL comments
  // ============================================================

  SCENARIO("SQL comment stripping") {
    auto* syntax = lang_syntax(".sql");
    REQUIRE(syntax != nullptr);

    GIVEN("SQL with -- line comment") {
      std::string input = "SELECT * FROM users; -- get all\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("-- comment is removed") {
          CHECK(result.find("--") == std::string::npos);
          CHECK(result.find("get all") == std::string::npos);
        }
        THEN("SQL is preserved") { CHECK(result.find("SELECT * FROM users;") != std::string::npos); }
      }
    }
  }

  // ============================================================
  // Lua comments
  // ============================================================

  SCENARIO("Lua comment stripping") {
    auto* syntax = lang_syntax(".lua");
    REQUIRE(syntax != nullptr);

    GIVEN("Lua with --[[ block comment ]]") {
      std::string input = "x = 1\n--[[ block\ncomment ]]\ny = 2\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("block comment is removed") {
          CHECK(result.find("block") == std::string::npos);
          CHECK(result.find("comment") == std::string::npos);
        }
        THEN("code is preserved") {
          CHECK(result.find("x = 1") != std::string::npos);
          CHECK(result.find("y = 2") != std::string::npos);
        }
      }
    }

    GIVEN("Lua with -- line comment") {
      std::string input = "x = 1 -- note\ny = 2\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("line comment is removed") { CHECK(result.find("note") == std::string::npos); }
      }
    }
  }

  // ============================================================
  // Ruby =begin/=end block comments
  // ============================================================

  SCENARIO("Ruby block comment stripping") {
    auto* syntax = lang_syntax(".rb");
    REQUIRE(syntax != nullptr);

    GIVEN("Ruby with =begin/=end block comment") {
      std::string input = "x = 1\n=begin\nThis is a\nblock comment\n=end\ny = 2\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("block comment content is removed") {
          CHECK(result.find("This is a") == std::string::npos);
          CHECK(result.find("block comment") == std::string::npos);
        }
        THEN("code is preserved") {
          CHECK(result.find("x = 1") != std::string::npos);
          CHECK(result.find("y = 2") != std::string::npos);
        }
        THEN("line count is preserved") { CHECK(count_lines(result) == count_lines(input)); }
      }
    }
  }

  // ============================================================
  // PHP dual comment syntax
  // ============================================================

  SCENARIO("PHP comment stripping") {
    auto* syntax = lang_syntax(".php");
    REQUIRE(syntax != nullptr);

    GIVEN("PHP with // and # comments") {
      std::string input = "$x = 1; // slash comment\n$y = 2; # hash comment\n";

      WHEN("comments are stripped") {
        std::string result = strip_comments(input, syntax);

        THEN("both comment styles are removed") {
          CHECK(result.find("slash comment") == std::string::npos);
          CHECK(result.find("hash comment") == std::string::npos);
        }
        THEN("code is preserved") {
          CHECK(result.find("$x = 1;") != std::string::npos);
          CHECK(result.find("$y = 2;") != std::string::npos);
        }
      }
    }
  }

  // ============================================================
  // Language coverage (ensure all 15+ languages are reachable)
  // ============================================================

  SCENARIO("all languages have syntax entries") {
    GIVEN("all documented extensions") {
      const char* exts[] = {
          ".c",   ".cpp", ".h",    ".hpp",  ".java", ".cs",   ".go",   ".rs",   ".swift", ".kt",     ".js",   ".ts",   ".jsx",
          ".tsx", ".vue", ".mjs",  ".py",   ".rb",   ".php",  ".sh",   ".bash", ".sql",   ".lua",    ".html", ".htm",  ".xml",
          ".svg", ".css", ".scss", ".less", ".yml",  ".yaml", ".toml", ".tf",   ".hcl",   ".tfvars", ".md",   nullptr,
      };

      THEN("each returns a non-null syntax entry") {
        for (int i = 0; exts[i]; i++) {
          INFO("Extension: " << exts[i]);
          CHECK(lang_syntax(exts[i]) != nullptr);
        }
      }
    }
  }
}
