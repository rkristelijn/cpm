---
summary: Port all checks to native C++. One binary, zero shell deps, mockable, JUnit output.
status: accepted
---

# ADR-022: Native C++ Architecture — No Shell Scripts

## Context

cpm currently has 35 shell scripts in `checks/` and `lib/shell/`. This causes:

- Not portable (bash 4+ required, macOS ships 3.2, Windows needs WSL)
- Slow (fork/exec per check, 30-60s for full suite)
- Hard to test (no mocking, no unit tests for shell)
- Not one binary (requires `~/.local/share/cpm/` with copied scripts)
- Inconsistent output (each script prints differently)

## Decision

Port all checks to native C++. The binary becomes fully self-contained.

### Architecture

```text
src/
├── main.cpp           ← CLI dispatch
├── commands.cpp       ← project commands (init, build, bump, etc.)
├── checks.cpp         ← check orchestration + native checks
├── runners/           ← tool runners (shell out + parse output)
│   ├── runner.h       ← ToolRunner interface (mockable)
│   ├── semgrep.cpp    ← run semgrep, parse JSON → findings
│   ├── gitleaks.cpp   ← run gitleaks, parse JSON → findings
│   ├── trivy.cpp      ← run trivy, parse JSON → findings
│   ├── cppcheck.cpp   ← run cppcheck, parse XML → findings
│   ├── eslint.cpp     ← run eslint/biome, parse JSON → findings
│   └── generic.cpp    ← run any tool, capture exit code
├── checks/            ← native checks (no external tools)
│   ├── check.h        ← Check interface (mockable)
│   ├── secrets.cpp    ← regex-based secret detection
│   ├── todo.cpp       ← TODO/FIXME extraction
│   ├── lockfile.cpp   ← lockfile existence
│   ├── runtime.cpp    ← EOL detection
│   ├── imports.cpp    ← deep import detection
│   ├── filesize.cpp   ← file size limits
│   └── ...
├── io/                ← mockable I/O layer
│   ├── filesystem.h   ← FileSystem interface
│   ├── filesystem.cpp ← real implementation
│   └── mock_fs.h      ← test mock
├── report/            ← output formatters
│   ├── junit.cpp      ← JUnit XML renderer
│   ├── jsonl.cpp      ← JSONL findings
│   └── console.cpp    ← terminal output (uses ui.h)
├── scan.cpp           ← polyrepo scanner
├── toml.cpp           ← config parser
└── ui.cpp             ← themed terminal output
```

### Interfaces (mockable)

```cpp
// io/filesystem.h — all file I/O goes through this
struct FileSystem {
  virtual bool exists(const char* path) = 0;
  virtual std::string read(const char* path) = 0;
  virtual std::vector<std::string> glob(const char* pattern) = 0;
  virtual ~FileSystem() = default;
};

// runners/runner.h — all tool execution goes through this
struct ToolRunner {
  virtual RunResult exec(const char* cmd) = 0;
  virtual bool has_tool(const char* name) = 0;
  virtual std::string tool_version(const char* name) = 0;
  virtual ~ToolRunner() = default;
};

// checks/check.h — all checks implement this
struct Check {
  const char* name;
  const char* category;  // "security", "quality", "style"
  virtual std::vector<Finding> run(FileSystem& fs, ToolRunner& runner) = 0;
  virtual ~Check() = default;
};
```

### JUnit as single output format

Every check, every tool runner, produces `Finding` structs:

```cpp
struct Finding {
  const char* check;     // "secrets-fast"
  const char* severity;  // "error" | "warning" | "info"
  const char* file;      // "src/main.cpp"
  int line;              // 42
  const char* rule;      // "hardcoded-secret"
  const char* message;   // "Potential API key detected"
  const char* fix;       // "Use environment variable"
};
```

These are rendered to:

- Console (colored, via ui.cpp)
- JUnit XML (for CI)
- JSONL (for querying)

### Tool version auto-detect

```cpp
// runners/semgrep.cpp
std::vector<Finding> SemgrepRunner::run(ToolRunner& runner) {
  std::string ver = runner.tool_version("semgrep");
  // semgrep >= 1.0 uses --json, older uses --json-output
  const char* flag = semver_gte(ver, "1.0.0") ? "--json" : "--json-output";
  auto result = runner.exec(fmt("semgrep scan --config auto %s", flag));
  return parse_semgrep_json(result.stdout);
}
```

### Test pyramid

| Layer | What | Speed | Mock |
|-------|------|-------|------|
| Unit | Check logic (regex, file parsing) | <1ms | MockFileSystem |
| Integration | Tool output parsers (fixture JSON/XML) | <10ms | fixture files |
| E2E | Full binary, all commands | <3s | MockToolRunner (CPM_MOCK) |

```cpp
// Unit test example
TEST_CASE("secrets check finds API keys") {
  MockFileSystem fs;
  fs.add_file("src/main.cpp", "auto key = \"sk-1234567890abcdef1234\";");

  SecretsCheck check;
  auto findings = check.run(fs, mock_runner);
  CHECK(findings.size() == 1);
  CHECK(findings[0].rule == "hardcoded-secret");
}

// Integration test example
TEST_CASE("semgrep parser handles v1.x JSON output") {
  auto json = read_fixture("fixtures/semgrep-1.57-output.json");
  auto findings = parse_semgrep_json(json);
  CHECK(findings.size() == 3);
  CHECK(findings[0].severity == "error");
}
```

### Install flow

```text
BEFORE:
  install.sh → copies binary + 50 shell scripts to ~/.local/share/cpm/

AFTER:
  brew install cpm          ← one binary, done
  # or:
  curl ... | sh             ← downloads binary to ~/.local/bin/cpm
  # or:
  sudo cp cpm /usr/local/bin/cpm

  cpm install               ← installs external tools (semgrep, gitleaks, etc.)
```

No `~/.local/share/cpm/` needed. No shell scripts to copy. One binary.

## Migration plan

1. **v0.1.0** — current state (shell scripts, works)
2. **v0.2.0** — add interfaces (FileSystem, ToolRunner, Check)
3. **v0.3.0** — port native checks (secrets, todo, lockfile, etc.)
4. **v0.4.0** — port tool runners (semgrep, gitleaks, trivy parsers)
5. **v0.5.0** — remove shell scripts, update install to single binary
6. **v1.0.0** — stable, all native, full test coverage

## Consequences

- **Pro**: one binary, portable (Windows without bash), fast, testable, consistent output
- **Pro**: mockable at every layer → fast tests, high coverage
- **Pro**: tool version handling → resilient to upstream changes
- **Con**: more C++ code to maintain (~2000 lines for checks + runners)
- **Con**: adding a new check requires recompile (vs dropping a .sh file)
- **Mitigation**: checks are simple (regex + file I/O), compile is <2s

## References

- @see docs/adrs/adr-013-product-positioning.md (one binary philosophy)
- @see docs/adrs/adr-020-product-vision.md (zero friction)
- @see docs/adrs/adr-014-findings-database.md (JSONL format)
