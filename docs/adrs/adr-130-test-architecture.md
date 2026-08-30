---
summary: Standardized test architecture — BDD style, tiered execution, consistent patterns across unit/integration/e2e.
status: partially-implemented
---

# ADR-130: Standardized Test Architecture

*Date*: 2026-05-19
*Related*: [ADR-129](adr-129-unified-findings-contract.md), [ADR-026](adr-026-v-model-process-enforcement.md)

## Context

cpm has 73 unit tests and 10 e2e tests, but uses almost none of doctest's features:

| doctest Feature | Available | Used? |
|-----------------|-----------|-------|
| `SCENARIO/GIVEN/WHEN/THEN` | ✅ | ❌ |
| `TEST_SUITE` | ✅ | ❌ |
| `SUBCASE` | ✅ | 1× |
| `REQUIRE` (fatal) | ✅ | ❌ |
| Fixtures | ✅ | ❌ |
| Parameterized | ✅ | ❌ |

**Problems:**

1. All tests are flat `TEST_CASE` — no structure, no grouping
2. No BDD language — tests don't describe behavior
3. E2E tests have no lifecycle hooks (beforeAll/afterAll)
4. No test profiling — slow tests go unnoticed
5. Unit tests compile as one 627-line monolith (8s cold compile)
6. No separation between fast/slow tests beyond `test-fast`

**What works well (from llama-cli):**

- BDD style: `SCENARIO/GIVEN/WHEN/THEN`
- RAII fixtures for cleanup (no manual teardown)
- Mock injection via interfaces (already in cpm)
- Separate `_test.cpp` per module

## Decision

### 1. BDD Style for Unit Tests (Given-When-Then)

All unit tests use doctest's BDD macros:

```cpp
TEST_SUITE("secrets") {
  SCENARIO("detecting hardcoded API keys") {
    GIVEN("a file containing an AWS key") {
      MockFileSystem fs;
      MockToolRunner r;
      fs.add_file("src/main.cpp", "auto k = \"AKIAIOSFODNN7EXAMPLE\";");

      WHEN("the secrets check runs") {
        auto findings = SecretsCheck().run(fs, r);

        THEN("it reports one error") {
          REQUIRE(findings.size() == 1);
          CHECK(findings[0].severity == "error");
          CHECK(findings[0].rule == "hardcoded-secret");
        }
      }
    }

    GIVEN("a clean file") {
      MockFileSystem fs;
      MockToolRunner r;
      fs.add_file("src/main.cpp", "int main() { return 0; }");

      WHEN("the secrets check runs") {
        auto findings = SecretsCheck().run(fs, r);

        THEN("it reports nothing") {
          CHECK(findings.empty());
        }
      }
    }
  }
}
```

### 2. TEST_SUITE for Grouping

Each check gets its own `TEST_SUITE`:

```cpp
TEST_SUITE("secrets") { ... }
TEST_SUITE("file-size") { ... }
TEST_SUITE("pii") { ... }
```

Benefits:

- Run one suite: `./build/test_checks -ts=secrets`
- Filter in CI: `./build/test_checks -ts=security*`
- Clear output grouping

### 3. REQUIRE vs CHECK

| Macro | Use when |
|-------|----------|
| `REQUIRE` | Precondition — test can't continue without this |
| `CHECK` | Assertion — test continues to show all failures |

```cpp
REQUIRE(findings.size() == 1);  // Fatal: can't index [0] if empty
CHECK(findings[0].severity == "error");  // Non-fatal: show all mismatches
CHECK(findings[0].file == "src/main.cpp");
```

### 4. RAII Fixtures (no manual teardown)

```cpp
// Fixture: auto-cleanup temp directory
struct TmpProject {
  std::string path;
  TmpProject() : path("/tmp/cpm-test-" + std::to_string(getpid())) {
    std::filesystem::create_directories(path);
  }
  ~TmpProject() { std::filesystem::remove_all(path); }
};

SCENARIO("scan finds repos") {
  GIVEN("a directory with git repos") {
    TmpProject tmp;
    // tmp auto-cleans on scope exit
  }
}
```

### 5. E2E Test Standard Pattern

```bash
#!/usr/bin/env bash
# test_<command>.sh — E2E test for cpm <command>
source "$(dirname "$0")/helpers.sh"
BINARY=$(resolve_binary "${1:-./cpm}")
check_binary "$BINARY"

echo "=== E2E: <command> ==="

# --- Setup (beforeAll) ---
DIR=$(setup_project)
(cd "$DIR" && "$BINARY" init)

# --- Tests (given-when-then as comments) ---

# Given: a project with cpm.toml
# When: running cpm check --fast
OUTPUT=$(cd "$DIR" && "$BINARY" check --fast 2>&1 || true)
# Then: output contains format results
assert_contains "$OUTPUT" "format" "check --fast runs format"

# --- Teardown (afterAll) ---
teardown_project "$DIR"

echo "=== All <command> tests passed ==="
```

### 6. Test Tiers (V-model mapping)

```text
┌─────────────────────────────────────────────────────┐
│ Tier 0: Compile        make build         ~8s cold  │
│         (syntax errors, type errors)       0s cached │
├─────────────────────────────────────────────────────┤
│ Tier 1: Unit (fast)    make test-fast      <1s      │
│         (toml parser, pure logic)                    │
├─────────────────────────────────────────────────────┤
│ Tier 2: Unit (all)     make test-unit      <2s      │
│         (all checks with mocks)                      │
├─────────────────────────────────────────────────────┤
│ Tier 3: E2E            make e2e            <10s     │
│         (binary, mock tools, real filesystem)        │
├─────────────────────────────────────────────────────┤
│ Tier 4: Integration    make test-live      <60s     │
│         (real tools: gitleaks, cppcheck, etc)        │
└─────────────────────────────────────────────────────┘
```

Mapping to git hooks:

- **pre-commit**: Tier 1 (test-fast, <1s)
- **pre-push**: Tier 2 + 3 (test-unit + e2e, <12s)
- **CI**: Tier 0-4 (all, <60s)

### 7. One Test File Per Module

Split `checks_test.cpp` (627 lines) into per-check test files:

```text
src/checks/
├── secrets.cpp
├── secrets_test.cpp      ← tests for secrets only
├── pii.cpp
├── pii_test.cpp          ← tests for pii only
├── filesize.cpp
├── filesize_test.cpp     ← tests for filesize only
└── ...
```

Build: each `*_test.cpp` compiles independently → parallel compilation, incremental builds.

```makefile
TEST_CHECK_SRCS = $(wildcard src/checks/*_test.cpp)
TEST_CHECK_BINS = $(patsubst src/checks/%_test.cpp,$(BUILD)/test_%,$(TEST_CHECK_SRCS))

$(BUILD)/test_%: src/checks/%_test.cpp src/checks/%.cpp src/io/filesystem.cpp | $(BUILD)
	$(CXX) $(CXXFLAGS) -I src -I vendor -o $@ $^

test-unit: $(BUILD)/test_toml $(TEST_CHECK_BINS)
	@for t in $^; do ./$$t || exit 1; done
```

### 8. Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Unit test file | `<module>_test.cpp` | `secrets_test.cpp` |
| E2E test file | `test_<command>.sh` | `test_check.sh` |
| TEST_SUITE | check name (kebab) | `TEST_SUITE("secrets")` |
| SCENARIO | behavior description | `SCENARIO("detecting API keys")` |
| GIVEN | precondition | `GIVEN("a file with an AWS key")` |
| WHEN | action | `WHEN("the check runs")` |
| THEN | assertion | `THEN("it reports one error")` |
| E2E function | `assert_<what>` | `assert_contains`, `assert_file_exists` |
| Mock class | `Mock<Interface>` | `MockFileSystem` |
| Fixture | `<Purpose>` (RAII) | `TmpProject`, `CaptureStderr` |
| Test binary | `test_<module>` | `build/test_secrets` |

### 9. Performance Budget

| Tier | Budget | Enforcement |
|------|--------|-------------|
| test-fast | <1s | Fail if exceeded |
| test-unit | <3s | Warn >2s, fail >5s |
| e2e | <10s | Warn >5s per test, fail >30s |
| test-live | <60s | CI only |

Enforced via `TEST_WARN_MS` / `TEST_FAIL_MS` in e2e runner.

For unit tests: doctest has `--duration=true` flag:

```bash
./build/test_checks --duration=true  # shows per-test timing
```

### 10. Comparison with Mature Frameworks

| Concept | Jest/Vitest | Cypress | JUnit 5 | doctest (our choice) |
|---------|-------------|---------|----------|---------------------|
| Grouping | `describe()` | `describe()` | `@Nested` | `TEST_SUITE` |
| Setup | `beforeEach()` | `beforeEach()` | `@BeforeEach` | `SUBCASE` or RAII fixture |
| Teardown | `afterEach()` | `afterEach()` | `@AfterEach` | RAII destructor |
| BDD | `it("should...")` | `it("should...")` | — | `SCENARIO/GIVEN/WHEN/THEN` |
| Assertions | `expect().toBe()` | `cy.get().should()` | `assertEquals()` | `CHECK()`, `REQUIRE()` |
| Parameterized | `it.each()` | — | `@ParameterizedTest` | `DOCTEST_VALUE_PARAMETERIZED_DATA` |
| Filtering | `--grep` | `--spec` | `--include-tag` | `-ts=`, `-tc=` |
| Parallel | `--workers` | `--parallel` | `@Execution(CONCURRENT)` | Not built-in |

**Why doctest is the right choice for cpm:**

- Zero dependencies (header-only, already vendored)
- BDD macros built-in (no extra library)
- Fast compilation (faster than Catch2)
- Filtering by suite/case name
- Duration reporting built-in
- C++17 compatible

**What we adopt from Jest/Vitest:**

- `describe` → `TEST_SUITE` (grouping)
- `beforeEach` → RAII fixture or `SUBCASE` (setup per test)
- `afterEach` → RAII destructor (automatic cleanup)
- `it("should...")` → `SCENARIO("...")` (behavior description)
- `expect().toBe()` → `CHECK(x == y)` (assertion)

**What we adopt from Cypress:**

- Retry on flaky (not yet — future)
- Screenshot on failure → JUnit XML with context (already have)
- Timeout per test → `TEST_FAIL_MS` (already have)

## Consequences

### Positive

- Consistent pattern across all tests (BDD, RAII, suites)
- Incremental compilation (per-check test binary)
- Clear performance budgets with enforcement
- Tests document behavior (GIVEN/WHEN/THEN reads like a spec)
- Filter by suite: `./build/test_secrets` or `./build/test_checks -ts=secrets`

### Negative

- Migration effort: rewrite 66 TEST_CASEs to SCENARIO style
- More files (one `_test.cpp` per check)
- RAII fixtures require C++ discipline

### Migration Path

1. Create `src/checks/secrets_test.cpp` as reference implementation
2. Add `TEST_SUITE` wrapper to existing `checks_test.cpp` (non-breaking)
3. Split one check at a time (each split is a commit)
4. Update Makefile with pattern rule for `test_%`
5. Add `--duration=true` to CI for profiling

## Acceptance Criteria

- [ ] All unit tests use `TEST_SUITE` + `SCENARIO/GIVEN/WHEN/THEN`
- [ ] Each check has its own `_test.cpp` (no monolith)
- [ ] `make test-unit` completes in <3s (cached)
- [ ] `make test-fast` completes in <1s
- [ ] E2E tests follow standard pattern (setup/test/teardown)
- [ ] Performance budget enforced (warn/fail thresholds)

## References

- @see ADR-129 (unified findings contract)
- @see ADR-026 (V-model process enforcement)
- @see vendor/doctest.h (framework docs)
- @see ../llama-cli/ (reference implementation)
- [doctest BDD](https://github.com/doctest/doctest/blob/master/doc/markdown/testcases.md#bdd-style-test-cases)
