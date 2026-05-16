# cpm — code project maturity

> AI writes the code. cpm keeps it good.

A quality layer between git and your code. One binary, zero friction, any repo.

## Install

```bash
# From source (requires g++ with C++17)
git clone https://github.com/rkristelijn/cpm.git
cd cpm && make build && sudo make install
```

## Quick start

```bash
cd my-project
cpm init          # generates cpm.toml with sensible defaults
cpm check --fast  # format + build (pre-commit)
cpm check         # + lint + test (pre-push)
cpm check --full  # + coverage + sast (CI)
```

## Commands

| Command | Description |
|---------|-------------|
| `cpm init` | Create cpm.toml in current directory |
| `cpm check [--fast\|--full]` | Run quality gate (tiered) |
| `cpm lint` | Run all lint checks |
| `cpm format` | Auto-format all files |
| `cpm build` | Build the project |
| `cpm run` | Build and run |
| `cpm test` | Run tests |
| `cpm coverage` | Build with coverage and report |
| `cpm scan <path>` | Scan repos for quality metrics |
| `cpm new <name>` | Create a new project |
| `cpm new test <name>` | Add a test file |
| `cpm new module <name>` | Add a module (cpp + hpp) |
| `cpm install` | Install tools from cpm.toml |
| `cpm eject` | Generate Makefile + CMakeLists.txt |
| `cpm hook` / `unhook` | Install/remove git hooks |
| `cpm bump <major\|minor\|patch>` | Bump version in cpm.toml |
| `cpm get [key]` | Show config |
| `cpm set <key> <val>` | Update config |
| `cpm audit` | Check tool versions |
| `cpm tools` | Show installed tool versions |

## How it works

```text
  You / AI → code → cpm → git → remote
                     ↑
                     formats, lints, scans
                     teaches why
                     tracks progress
```

cpm detects your build system (Make, CMake, or raw compiler) and orchestrates quality tools in parallel. No config needed — sensible defaults work out of the box.

## Configuration

```toml
# cpm.toml
[project]
name = "my-project"
version = "0.1.0"
lang = "cpp"
build = "make"

[tools]
llvm = "19"
cppcheck = "2.13"
gitleaks = "8.18.2"

[checks]
code-cpp-syntax-format = true
code-generic-secrets-scan = true

[hooks]
pre-commit = true
pre-push = true
```

## Quality checks (built-in)

| Check | Tool | What it does |
|-------|------|-------------|
| Format C++ | clang-format | Code style consistency |
| Format YAML | yamllint | YAML syntax + style |
| Format Markdown | rumdl | Markdown lint |
| Format scripts | shfmt | Shell formatting |
| Lint C++ | cppcheck | Static analysis |
| Lint C++ quality | clang-tidy | Readability + bugs |
| Lint scripts | shellcheck | Shell best practices |
| Complexity | pmccabe | Cyclomatic complexity ≤ 10 |
| Comment ratio | cloc | Minimum 20% comments |
| Docs | doxygen | Documentation warnings |
| Vulnerability scan | semgrep | SAST security |
| Secrets scan | gitleaks | No secrets in code |

## Design principles

- **Zero friction** — works without config, without committing anything
- **One binary** — 92KB, no runtime dependencies
- **Fast** — checks run in parallel, pre-commit < 5s
- **Shift left** — fail fast, fail smart, fail at your level
- **Learn don't police** — every message teaches

## License

MIT
