/**
 * @file platform_test.cpp
 * @brief Unit tests for the platform abstraction layer (platform_posix.cpp).
 * @see ADR-130 for test architecture (TEST_SUITE + SCENARIO/GIVEN/WHEN/THEN)
 * @see ADR-170 for the platform abstraction rationale
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "platform.h"

#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>
#include <string>

#include "../../vendor/doctest.h"

/* ── Test helpers ───────────────────────────────────────────── */

static std::string unique_tmp_path(const std::string& suffix) {
  return "/tmp/cpm_platform_test_" + std::to_string(getpid()) + "_" + suffix;
}

TEST_SUITE("platform") {
  // ============================================================
  // os_kind
  // ============================================================

  SCENARIO("os_kind reports a concrete POSIX platform") {
    GIVEN("a binary built for macOS or Linux") {
      WHEN("os_kind is queried") {
        auto kind = platform::os_kind();

        THEN("it returns a known POSIX family, never Windows/Unknown") {
          bool posix = kind == platform::OsKind::MacOS || kind == platform::OsKind::Linux || kind == platform::OsKind::Alpine;
          CHECK(posix);
          CHECK(kind != platform::OsKind::Windows);
          CHECK(kind != platform::OsKind::Unknown);
        }
      }
    }
  }

  // ============================================================
  // executable_path / executable_dir
  // ============================================================

  SCENARIO("executable_path resolves to the running test binary") {
    GIVEN("the running process") {
      WHEN("executable_path is queried") {
        std::string path = platform::executable_path();

        THEN("it returns a non-empty absolute path") {
          REQUIRE(!path.empty());
          CHECK(path.front() == '/');
        }
        THEN("the path points to an existing file") {
          struct stat st;
          CHECK(stat(path.c_str(), &st) == 0);
        }
      }
    }
  }

  SCENARIO("executable_dir is the parent directory of executable_path") {
    GIVEN("a resolved executable path") {
      std::string path = platform::executable_path();
      std::string dir = platform::executable_dir();

      WHEN("both are compared") {
        THEN("the dir has no trailing slash and prefixes the path") {
          REQUIRE(!dir.empty());
          CHECK(dir.back() != '/');
          /* executable_path should start with dir + "/" */
          CHECK(path.rfind(dir + "/", 0) == 0);
        }
        THEN("the directory exists") {
          struct stat st;
          CHECK(stat(dir.c_str(), &st) == 0);
          CHECK(S_ISDIR(st.st_mode));
        }
      }
    }
  }

  // ============================================================
  // now_sec
  // ============================================================

  SCENARIO("now_sec is monotonic and non-negative") {
    GIVEN("two successive time samples") {
      double t0 = platform::now_sec();
      double t1 = platform::now_sec();

      WHEN("compared") {
        THEN("time never goes backwards") {
          CHECK(t0 >= 0.0);
          CHECK(t1 >= t0);
        }
      }
    }
  }

  // ============================================================
  // wait_exit
  // ============================================================

  SCENARIO("wait_exit decodes a normal child exit status") {
    GIVEN("a child that exits with code 0") {
      pid_t pid = fork();
      REQUIRE(pid >= 0);
      if (pid == 0) _exit(0);
      int raw = 0;
      waitpid(pid, &raw, 0);

      WHEN("the raw status is decoded") {
        THEN("wait_exit returns 0") { CHECK(platform::wait_exit(raw) == 0); }
      }
    }

    GIVEN("a child that exits with code 42") {
      pid_t pid = fork();
      REQUIRE(pid >= 0);
      if (pid == 0) _exit(42);
      int raw = 0;
      waitpid(pid, &raw, 0);

      WHEN("the raw status is decoded") {
        THEN("wait_exit returns 42") { CHECK(platform::wait_exit(raw) == 42); }
      }
    }
  }

  // ============================================================
  // cmd_which / cmd_version / cmd_with_timeout
  // ============================================================

  SCENARIO("cmd_which builds a PATH-probe command") {
    GIVEN("a tool name") {
      WHEN("cmd_which is built") {
        std::string cmd = platform::cmd_which("git");

        THEN("it uses 'command -v' and suppresses output") {
          CHECK(cmd.find("command -v git") != std::string::npos);
          CHECK(cmd.find(">/dev/null") != std::string::npos);
        }
        THEN("the command actually detects an installed tool (sh)") {
          /* 'sh' is guaranteed on any POSIX system */
          CHECK(system(platform::cmd_which("sh").c_str()) == 0);
        }
        THEN("the command reports a missing tool as non-zero") {
          std::string missing = platform::cmd_which("cpm_definitely_not_a_tool_xyz");
          CHECK(system(missing.c_str()) != 0);
        }
      }
    }
  }

  SCENARIO("cmd_version builds a version-probe command") {
    GIVEN("a tool name") {
      WHEN("cmd_version is built") {
        std::string cmd = platform::cmd_version("git");

        THEN("it requests --version and takes the first line") {
          CHECK(cmd.find("git --version") != std::string::npos);
          CHECK(cmd.find("head -1") != std::string::npos);
        }
      }
    }
  }

  SCENARIO("cmd_with_timeout wraps commands based on the timeout") {
    GIVEN("a positive timeout") {
      WHEN("the command is wrapped") {
        std::string cmd = platform::cmd_with_timeout("echo hi", 5);

        THEN("it prepends 'timeout 5' and redirects stderr") {
          CHECK(cmd.find("timeout 5 echo hi") != std::string::npos);
          CHECK(cmd.find("2>&1") != std::string::npos);
        }
      }
    }

    GIVEN("a zero timeout") {
      WHEN("the command is wrapped") {
        std::string cmd = platform::cmd_with_timeout("echo hi", 0);

        THEN("no timeout util is used but stderr is still redirected") {
          CHECK(cmd.find("timeout") == std::string::npos);
          CHECK(cmd.find("2>&1") != std::string::npos);
        }
      }
    }
  }

  // ============================================================
  // is_symlink
  // ============================================================

  SCENARIO("is_symlink distinguishes symlinks from regular files") {
    GIVEN("a regular file and a symlink pointing at it") {
      std::string target = unique_tmp_path("target");
      std::string link = unique_tmp_path("link");
      unlink(target.c_str());
      unlink(link.c_str());

      FILE* f = fopen(target.c_str(), "w");
      REQUIRE(f != nullptr);
      fputs("data\n", f);
      fclose(f);
      REQUIRE(symlink(target.c_str(), link.c_str()) == 0);

      WHEN("each path is checked") {
        THEN("the regular file is not a symlink") { CHECK(platform::is_symlink(target) == false); }
        THEN("the symlink is detected as a symlink") { CHECK(platform::is_symlink(link) == true); }
        THEN("a non-existent path is not a symlink") { CHECK(platform::is_symlink(unique_tmp_path("nope")) == false); }
      }

      unlink(link.c_str());
      unlink(target.c_str());
    }
  }

  // ============================================================
  // make_dir
  // ============================================================

  SCENARIO("make_dir creates nested directories and is idempotent") {
    GIVEN("a nested path under a unique temp root") {
      std::string root = unique_tmp_path("mkdir");
      std::string nested = root + "/a/b/c";
      /* best-effort cleanup of any prior run */
      rmdir((root + "/a/b/c").c_str());
      rmdir((root + "/a/b").c_str());
      rmdir((root + "/a").c_str());
      rmdir(root.c_str());

      WHEN("make_dir is called on the nested path") {
        bool ok = platform::make_dir(nested);

        THEN("it succeeds and every level exists as a directory") {
          CHECK(ok == true);
          struct stat st;
          REQUIRE(stat(nested.c_str(), &st) == 0);
          CHECK(S_ISDIR(st.st_mode));
        }
        THEN("calling it again on an existing path still succeeds (idempotent)") { CHECK(platform::make_dir(nested) == true); }
      }

      /* teardown deepest-first */
      rmdir((root + "/a/b/c").c_str());
      rmdir((root + "/a/b").c_str());
      rmdir((root + "/a").c_str());
      rmdir(root.c_str());
    }

    GIVEN("an empty path") {
      WHEN("make_dir is called") {
        THEN("it returns false") { CHECK(platform::make_dir("") == false); }
      }
    }

    GIVEN("a relative nested path with a leading ./ (dot segment)") {
      /* Exercises the dot-segment branch (acc == "."): a leading "./" must be
         skipped without trying to mkdir ".". */
      std::string base = "cpm_reltest_" + std::to_string(getpid());
      std::string rel = "./" + base + "/x/y";
      rmdir((base + "/x/y").c_str());
      rmdir((base + "/x").c_str());
      rmdir(base.c_str());

      WHEN("make_dir is called on the ./-prefixed path") {
        bool ok = platform::make_dir(rel);
        THEN("it succeeds and the nested dir exists") {
          CHECK(ok == true);
          struct stat st;
          CHECK(stat((base + "/x/y").c_str(), &st) == 0);
        }
      }

      rmdir((base + "/x/y").c_str());
      rmdir((base + "/x").c_str());
      rmdir(base.c_str());
    }
  }

}  // TEST_SUITE("platform")
