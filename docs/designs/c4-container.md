# C4 Container Diagram — cpm

Shows the internal structure of the cpm binary and its runtime components.

```mermaid
C4Container
    title Container Diagram — cpm internals

    Person(dev, "Developer", "")

    System_Boundary(cpm, "cpm") {
        Container(cli, "CLI Dispatch", "C++", "main.cpp — routes argv to command handlers")
        Container(commands, "Commands", "C++", "commands.cpp, cmd_ops.cpp — project operations")
        Container(checks, "Check Engine", "C++", "checks.cpp — parallel runner, tiered gates")
        Container(native_checks, "Native Checks", "C++", "33 in-process checks (security, quality, deps)")
        Container(scanner, "Polyrepo Scanner", "C++", "scan.cpp — file-based, <1s for 100+ repos")
        Container(toml, "TOML Parser", "C++", "toml.cpp — minimal parser for cpm.toml")
        Container(junit, "JUnit Reporter", "C++", "junit.cpp — XML output for CI integration")
        Container(shell_fw, "Shell Framework", "Bash", "lib/shell/ — UI, timing, findings, maturity")
        Container(check_scripts, "Check Scripts", "Bash", "checks/cpp/, checks/universal/ — tool wrappers")
    }

    System_Ext(tools, "Quality Tools", "gitleaks, semgrep, clang-format, cppcheck")
    System_Ext(fs, "Filesystem", "cpm.toml, source files, .git/")
    System_Ext(findings, "Findings DB", "~/.local/share/cpm/*.jsonl")

    Rel(dev, cli, "cpm <command>")
    Rel(cli, commands, "Dispatches")
    Rel(cli, scanner, "cpm scan")
    Rel(commands, checks, "cpm check/lint")
    Rel(checks, native_checks, "In-process")
    Rel(checks, check_scripts, "Shell out via runner")
    Rel(check_scripts, tools, "Invokes with timeout")
    Rel(commands, toml, "Reads config")
    Rel(checks, junit, "Generates reports")
    Rel(scanner, fs, "File I/O only")
    Rel(checks, findings, "Writes JSONL")
    Rel(commands, shell_fw, "commit, issue, phase")
```

## Container responsibilities

| Container | Responsibility | Performance target |
|-----------|---------------|-------------------|
| CLI Dispatch | Route command, detect recursion, show version | <1ms |
| Commands | Build, test, format, hooks, config, eject | Varies |
| Check Engine | Parallel execution, tiering, mock support | <60s (default tier) |
| Native Checks | In-process file analysis, no tool deps | <5s total |
| Scanner | Discover repos, score maturity, emit findings | <1s for 100+ repos |
| TOML Parser | Parse cpm.toml, provide defaults | <1ms |
| JUnit Reporter | Serialize findings to XML | <10ms |
| Shell Framework | TUI output, timing, git operations | N/A |
| Check Scripts | Wrap external tools, parse output | Per-tool timeout |

## Design decisions

- **C++ binary + bash scripts**: binary for speed (scan, native checks), bash for tool orchestration (portable, inspectable)
- **Fork-based parallelism**: each check runs in a child process (isolation, no shared state)
- **JSONL findings**: append-only, streamable, queryable without a database
- **Tiered gates**: fast (<5s) for pre-commit, default (<60s) for pre-push, full for CI
- **CPM_MOCK**: env var skips tool execution for instant e2e testing
