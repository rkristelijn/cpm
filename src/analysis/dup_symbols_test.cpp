/**
 * @file dup_symbols_test.cpp
 * @brief Unit tests for generic duplicate-symbol detection.
 * @see ADR-130 (test architecture) ADR-170 (motivating case)
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#include <fstream>

#include "../../vendor/doctest.h"
#include "dup_symbols.h"

static std::string create_temp_dir() {
  char template_path[] = "/tmp/cpm_dup_symbols_test_XXXXXX";
  char* dir = mkdtemp(template_path);
  return dir ? std::string(dir) : "";
}

static void write_file(const std::string& path, const std::string& content) {
  std::ofstream out(path);
  out << content;
}

static void remove_recursive(const std::string& path) {
  DIR* d = opendir(path.c_str());
  if (!d) { unlink(path.c_str()); return; }
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

static bool has_dup(const std::vector<DupFinding>& fs, const std::string& name) {
  for (const auto& f : fs)
    if (f.name == name) return true;
  return false;
}

TEST_SUITE("dup-symbols") {

  SCENARIO("extract functions from a single file") {
    GIVEN("a C++ file with two functions") {
      std::string content =
          "int add(int a, int b) {\n"
          "  return a + b;\n"
          "}\n"
          "\n"
          "static const char* greet() {\n"
          "  return \"hi\";\n"
          "}\n";
      WHEN("symbols are extracted") {
        auto syms = extract_symbols(content, ".cpp", "a.cpp");
        THEN("both functions are found") {
          CHECK(syms.size() == 2);
          bool has_add = false, has_greet = false;
          for (const auto& s : syms) {
            if (s.name == "add") has_add = true;
            if (s.name == "greet") has_greet = true;
            CHECK(s.kind == SymbolKind::Function);
          }
          CHECK(has_add);
          CHECK(has_greet);
        }
      }
    }
  }

  SCENARIO("identical function copy-pasted across two files is flagged") {
    GIVEN("the same strcasestr fallback in two files") {
      std::string body =
          "static const char* strcasestr(const char* haystack, const char* needle) {\n"
          "  if (!needle[0]) return haystack;\n"
          "  for (; *haystack; haystack++) {\n"
          "    const char* h = haystack;\n"
          "    const char* n = needle;\n"
          "    while (*h && *n) { h++; n++; }\n"
          "    if (!*n) return haystack;\n"
          "  }\n"
          "  return nullptr;\n"
          "}\n";
      std::vector<Symbol> syms;
      auto a = extract_symbols(body, ".cpp", "scan_a.cpp");
      auto b = extract_symbols(body, ".cpp", "scan_b.cpp");
      syms.insert(syms.end(), a.begin(), a.end());
      syms.insert(syms.end(), b.begin(), b.end());

      WHEN("duplicates are detected") {
        auto fs = find_duplicate_symbols(syms);
        THEN("strcasestr is reported as a duplicate function") {
          CHECK(has_dup(fs, "strcasestr"));
          bool found = false;
          for (const auto& f : fs) {
            if (f.name == "strcasestr") {
              found = true;
              CHECK(f.type == "duplicate-function");
              CHECK(f.locations.size() == 2);
            }
          }
          CHECK(found);
        }
      }
    }
  }

  SCENARIO("whitespace/indentation differences still count as duplicates") {
    GIVEN("the same function formatted differently in two files") {
      std::string tight = "int f(int x){return x*2;}\n";
      std::string loose = "int f(int x) {\n    return x * 2;\n}\n";
      std::vector<Symbol> syms;
      auto a = extract_symbols(tight, ".cpp", "a.cpp");
      auto b = extract_symbols(loose, ".cpp", "b.cpp");
      syms.insert(syms.end(), a.begin(), a.end());
      syms.insert(syms.end(), b.begin(), b.end());
      WHEN("duplicates are detected") {
        auto fs = find_duplicate_symbols(syms);
        THEN("f is flagged despite formatting differences") {
          CHECK(has_dup(fs, "f"));
        }
      }
    }
  }

  SCENARIO("same name but different body is NOT a duplicate") {
    GIVEN("two functions named init with different bodies") {
      std::string a = "void init() {\n  setup_a();\n}\n";
      std::string b = "void init() {\n  setup_b();\n  extra();\n}\n";
      std::vector<Symbol> syms;
      auto sa = extract_symbols(a, ".cpp", "a.cpp");
      auto sb = extract_symbols(b, ".cpp", "b.cpp");
      syms.insert(syms.end(), sa.begin(), sa.end());
      syms.insert(syms.end(), sb.begin(), sb.end());
      WHEN("duplicates are detected") {
        auto fs = find_duplicate_symbols(syms);
        THEN("init is NOT reported (bodies differ)") {
          CHECK_FALSE(has_dup(fs, "init"));
        }
      }
    }
  }

  SCENARIO("duplicate within a single file is NOT flagged (needs 2+ files)") {
    GIVEN("the same body twice in one file") {
      std::string content =
          "int a(int x) { return x + 1; }\n"
          "int b(int x) { return x + 1; }\n";
      WHEN("duplicates are detected") {
        // Same body, same file, different names → different names means
        // different symbols; and even identical bodies here live in one file.
        auto syms = extract_symbols(content, ".cpp", "same.cpp");
        auto fs = find_duplicate_symbols(syms);
        THEN("nothing is reported (single-file)") {
          CHECK(fs.empty());
        }
      }
    }
  }

  SCENARIO("full pipeline over a directory") {
    GIVEN("a temp dir with a duplicated helper across two files") {
      std::string dir = create_temp_dir();
      REQUIRE(!dir.empty());
      std::string helper =
          "static int clamp(int v, int lo, int hi) {\n"
          "  if (v < lo) return lo;\n"
          "  if (v > hi) return hi;\n"
          "  return v;\n"
          "}\n";
      write_file(dir + "/one.cpp", helper + "int one() { return clamp(5,0,9); }\n");
      write_file(dir + "/two.cpp", helper + "int two() { return clamp(1,2,3); }\n");

      WHEN("the pipeline runs") {
        auto fs = analyze_duplicate_symbols(dir);
        THEN("clamp is reported as duplicated across the two files") {
          CHECK(has_dup(fs, "clamp"));
        }
      }
      remove_recursive(dir);
    }
  }
}
