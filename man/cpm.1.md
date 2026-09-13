% CPM(1) cpm 0.10.0 | Code Project Maturity
% Remi Kristelijn
% September 2026

# NAME

cpm - code project maturity: quality gate, rule engine, and project scaffolding

# SYNOPSIS

**cpm** *command* [*options*]

# DESCRIPTION

**cpm** is a fast, self-contained code-project-maturity tool. It runs a tiered
quality gate (format, lint, test, SAST), a fuzzy/AST-aware rule engine over a
bundled rule corpus, and project scaffolding and reporting helpers.

Output is designed to be accessible: findings are emitted as clickable
*file:line* references, and this man page provides a screen-reader-friendly
alternative to **--help**.

# COMMANDS

## Project lifecycle

**new** *name*
: Create a new project. Convention: *<domain>-<flavor>-<intent>-<method>*
  (e.g. `code-cpp-vulnerability-scan`).

**new test** *name*
: Add a new test file (e.g. `cpm new test parser`).

**new module** *name*
: Add a module (`src/name.cpp` + `src/name.hpp`).

**init**
: Create a new `cpm.toml` in the current directory.

**install**
: Install tools declared in `cpm.toml`.

**uninstall** [**--all**]
: Remove cpm from PATH. With **--all**, also remove installed tools.

**eject**
: Generate a `Makefile` and `CMakeLists.txt`.

### Quality gate

**check** [**--fast**|**--full**]
: Run the tiered quality gate. **--fast** runs the quickest tier only;
  **--full** runs every tier.

**lint**
: Run all lint checks.

**format**
: Auto-format all files.

**build**
: Build the project.

**run**
: Build and run the project.

**test**
: Run tests.

**coverage** [**--sonar**]
: Build with coverage and report. **--sonar** emits XML.

**clean**
: Remove build artifacts.

**audit**
: Check installed tool versions against `cpm.toml`.

### Rules, findings and reporting

**scan** *path*
: Scan one or more repositories for quality metrics and rule findings.

**score**
: Show the maturity score (0-100) and badge.

**findings** [*repo*]
: Query findings. Options: **--severity** *level*, **--junit**.

**report**
: Generate a report from recorded findings.

**xref**
: Validate all cross-references.

**todo**
: Show TODO/FIXME items collected by the scraper.

### Version and configuration

**version** [*part*]
: Show the version, or bump it (*part* = major|minor|patch).

**bump** *part*
: Bump the version (major|minor|patch).

**tools**
: Show installed tool versions.

**get** [*key*]
: Show configuration (all values, or a specific *key*).

**set** *key* *value*
: Update a configuration value.

**sort** *op*
: Canonical sort (**check**|**fix**) for cpm-toml, ts-imports, or lines.

**docs index** [*dir*] [**--check**]
: Generate a Markdown index of a docs directory. **--check** verifies it is
  up to date without writing.

### Git integration

**hook**
: Install git hooks for the current repository.

**hook --global**
: Install global pre-commit security hooks.

**hook --global --check**
: Verify global hook health.

**hook --global --status**
: Show which checks are enabled or disabled.

**hook --global --enable** *check*
: Enable a specific check.

**hook --global --disable** *check*
: Disable a specific check.

**hook --global --remove**
: Remove the global hooks.

**unhook**
: Remove per-repository git hooks.

**commit**
: Interactive Conventional Commit helper.

**issue** [*title*]
: Local-first issue tracking (push/pull to GitHub).

# EXIT STATUS

**0**
: Success, or no blocking findings.

**1**
: One or more blocking (error-severity) findings, or a command failure.

# FILES

*cpm.toml*
: Per-project configuration (tools, version, check settings).

*.config/.pii*, *~/.local/share/pii/patterns.d/\*.pii*
: PII detection pattern sources for the PII check.

# EXAMPLES

Run the fast quality gate in the current repository:

    cpm check --fast

Scan a directory tree and show the maturity score:

    cpm scan . && cpm score

Query only error-severity findings as JUnit XML:

    cpm findings --severity error --junit

# SEE ALSO

Full documentation: <https://github.com/rkristelijn/cpm>

# BUGS

Report issues at <https://github.com/rkristelijn/cpm/issues>.
