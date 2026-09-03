/**
 * @file runner_test.cpp
 * @brief Unit tests for the POSIX parallel execution engine (runner_posix.cpp).
 *
 * Exercises the real fork()/pipe()/waitpid() path with fast shell built-ins
 * (true/false/echo) so no external tools are required. The CPM_MOCK path is
 * also covered.
 *
 * @see ADR-130 for test architecture (TEST_SUITE + SCENARIO/GIVEN/WHEN/THEN)
 * @see ADR-170 for the platform-split rationale
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <cstdlib>
#include <string>

#include "../../vendor/doctest.h"
#include "constants.h"
#include "runner.h"
#include "runner_internal.h"

/* Ensure cpm_run_parallel does NOT wrap commands in the `timeout` binary,
 * which is not installed by default on macOS (it lives in coreutils as
 * gtimeout). Wrapping would make `timeout 30 sh -c 'true'` fail with
 * "command not found" on CI. CPM_TIMEOUT=0 selects the verbatim path so we
 * test the runner logic itself; the timeout-wrapping string is covered
 * separately by the cpm_wrap_command scenarios. */
namespace {
struct DisableTimeoutWrapper {
  DisableTimeoutWrapper() { setenv("CPM_TIMEOUT", "0", 1); }
};
static const DisableTimeoutWrapper g_disable_timeout_wrapper;
}  // namespace

TEST_SUITE("runner-posix") {

  SCENARIO("a passing command is counted as passed") {
    GIVEN("a single check that always succeeds") {
      const char* names[] = {"ok"};
      const char* commands[] = {"true"};
      const bool warn[] = {false};

      WHEN("the batch runs in parallel") {
        RunSummary s = cpm_run_parallel(names, commands, warn, 1);

        THEN("it reports one pass, zero failures") {
          CHECK(s.count == 1);
          CHECK(s.passed == 1);
          CHECK(s.failed == 0);
          CHECK(s.skipped == 0);
          CHECK(s.results[0].exit_code == 0);
          CHECK(s.results[0].skipped == false);
        }
        free(s.results);
      }
    }
  }

  SCENARIO("a failing command is counted as failed") {
    GIVEN("a single check that always fails and is not warn-only") {
      const char* names[] = {"boom"};
      const char* commands[] = {"false"};
      const bool warn[] = {false};

      WHEN("the batch runs") {
        RunSummary s = cpm_run_parallel(names, commands, warn, 1);

        THEN("it reports one failure with a non-zero exit code") {
          CHECK(s.failed == 1);
          CHECK(s.passed == 0);
          CHECK(s.results[0].exit_code != 0);
        }
        free(s.results);
      }
    }
  }

  SCENARIO("a failing warn-only command is counted as warned, not failed") {
    GIVEN("a failing check marked warn_only") {
      const char* names[] = {"lint"};
      const char* commands[] = {"false"};
      const bool warn[] = {true};

      WHEN("the batch runs") {
        RunSummary s = cpm_run_parallel(names, commands, warn, 1);

        THEN("it is warned, not failed") {
          CHECK(s.warned == 1);
          CHECK(s.failed == 0);
          CHECK(s.results[0].warn_only == true);
        }
        free(s.results);
      }
    }
  }

  SCENARIO("a null or empty command is skipped") {
    GIVEN("checks with a null command and an empty command") {
      const char* names[] = {"missing-tool", "empty-cmd"};
      const char* commands[] = {nullptr, ""};
      const bool warn[] = {false, false};

      WHEN("the batch runs") {
        RunSummary s = cpm_run_parallel(names, commands, warn, 2);

        THEN("both are skipped, none pass or fail") {
          CHECK(s.skipped == 2);
          CHECK(s.passed == 0);
          CHECK(s.failed == 0);
          CHECK(s.results[0].skipped == true);
          CHECK(s.results[1].skipped == true);
        }
        free(s.results);
      }
    }
  }

  SCENARIO("mixed batch aggregates pass/fail/warn/skip correctly") {
    GIVEN("a pass, a fail, a warn-only fail, and a skip") {
      const char* names[] = {"pass", "fail", "warn", "skip"};
      const char* commands[] = {"true", "false", "false", nullptr};
      const bool warn[] = {false, false, true, false};

      WHEN("the batch runs") {
        RunSummary s = cpm_run_parallel(names, commands, warn, 4);

        THEN("each category is counted once") {
          CHECK(s.count == 4);
          CHECK(s.passed == 1);
          CHECK(s.failed == 1);
          CHECK(s.warned == 1);
          CHECK(s.skipped == 1);
        }
        THEN("results preserve input order") {
          CHECK(std::string(s.results[0].name) == "pass");
          CHECK(std::string(s.results[3].name) == "skip");
        }
        THEN("total wall-clock time is non-negative") {
          CHECK(s.total_sec >= 0.0);
        }
        free(s.results);
      }
    }
  }

  SCENARIO("cpm_wrap_command wraps with a timeout and escapes single quotes") {
    GIVEN("a command containing single quotes and a positive timeout") {
      char out[CPM_WRAPPED_CMD_BUF];

      WHEN("it is wrapped with a 10s timeout") {
        bool ok = cpm_wrap_command(out, sizeof(out), "echo 'hi there'", 10);

        THEN("it succeeds and produces a timeout + sh -c wrapper") {
          REQUIRE(ok);
          CHECK(std::string(out).rfind("timeout 10 sh -c '", 0) == 0);
        }
        THEN("embedded single quotes are shell-escaped") {
          /* ' becomes '\'' */
          CHECK(std::string(out).find("'\\''hi there'\\''") != std::string::npos);
        }
      }
    }
  }

  SCENARIO("cpm_wrap_command copies verbatim when timeout is disabled") {
    GIVEN("a command and a zero/negative timeout") {
      char out[CPM_WRAPPED_CMD_BUF];

      WHEN("wrapped with timeout 0") {
        bool ok = cpm_wrap_command(out, sizeof(out), "make build", 0);
        THEN("the command is copied unchanged, no timeout wrapper") {
          REQUIRE(ok);
          CHECK(std::string(out) == "make build");
        }
      }

      WHEN("wrapped with a negative timeout") {
        bool ok = cpm_wrap_command(out, sizeof(out), "ls -la", -5);
        THEN("the command is copied unchanged") {
          REQUIRE(ok);
          CHECK(std::string(out) == "ls -la");
        }
      }
    }
  }

  SCENARIO("cpm_wrap_command rejects invalid arguments and overflow") {
    GIVEN("a null output buffer or null command") {
      char out[16];
      THEN("null command is rejected") {
        CHECK(cpm_wrap_command(out, sizeof(out), nullptr, 0) == false);
      }
      THEN("zero-size buffer is rejected") {
        CHECK(cpm_wrap_command(out, 0, "echo hi", 0) == false);
      }
    }

    GIVEN("a command that does not fit the destination buffer") {
      char tiny[8];
      WHEN("copied verbatim into a too-small buffer") {
        bool ok = cpm_wrap_command(tiny, sizeof(tiny), "this command is far too long", 0);
        THEN("it reports failure rather than truncating silently") {
          CHECK(ok == false);
        }
      }
      WHEN("wrapped with timeout into a too-small buffer") {
        bool ok = cpm_wrap_command(tiny, sizeof(tiny), "some command", 30);
        THEN("it reports failure") { CHECK(ok == false); }
      }
    }
  }

  SCENARIO("CPM_MOCK short-circuits execution to success") {
    GIVEN("a command that would normally fail, with CPM_MOCK set") {
      setenv("CPM_MOCK", "1", 1);
      const char* names[] = {"would-fail"};
      const char* commands[] = {"false"};
      const bool warn[] = {false};

      WHEN("the batch runs under the mock") {
        RunSummary s = cpm_run_parallel(names, commands, warn, 1);

        THEN("the child exits 0 and the check passes") {
          CHECK(s.passed == 1);
          CHECK(s.failed == 0);
          CHECK(s.results[0].exit_code == 0);
        }
        free(s.results);
      }
      unsetenv("CPM_MOCK");
    }
  }

  SCENARIO("a command producing large output does not deadlock") {
    GIVEN("a check that writes far more than one pipe buffer, then fails") {
      /* Emit ~200 KiB (> 64 KiB pipe capacity). The runner must drain the
       * pipe before waitpid or it deadlocks. The captured output is printed
       * to stderr on failure — that is expected runner behavior. */
      const char* names[] = {"noisy"};
      const char* commands[] = {"yes AAAA | head -c 200000; false"};
      const bool warn[] = {false};

      WHEN("the batch runs") {
        RunSummary s = cpm_run_parallel(names, commands, warn, 1);

        THEN("it completes and is counted as failed (no hang)") {
          CHECK(s.count == 1);
          CHECK(s.failed == 1);
        }
        free(s.results);
      }
    }
  }

}  // TEST_SUITE("runner-posix")
