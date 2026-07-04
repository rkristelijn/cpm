# cpm — code project maturity

![maturity](https://img.shields.io/badge/maturity-level%203-yellow)
![tests](https://img.shields.io/badge/tests-131%20passed-brightgreen)
![checks](https://img.shields.io/badge/checks-136-blue)
![languages](https://img.shields.io/badge/languages-14-blue)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=rkristelijn_cpm&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=rkristelijn_cpm)
![license](https://img.shields.io/badge/license-MIT-green)
[![GitHub release](https://img.shields.io/github/v/release/rkristelijn/cpm)](https://github.com/rkristelijn/cpm/releases/latest)
[![GitHub downloads](https://img.shields.io/github/downloads/rkristelijn/cpm/total)](https://github.com/rkristelijn/cpm/releases)
![homebrew](https://img.shields.io/badge/homebrew-tap-orange)
![curl](https://img.shields.io/badge/install-curl%20%7C%20bash-blue)

A quality layer between git and your code. One binary, zero friction, any repo.

![cpm demo](docs/features/demo.gif)

## How it works

One command. Any repo. Zero config required.

```bash
cd my-project && cpm check
```

cpm hooks into git and runs quality checks automatically — formatting on commit, linting on push, learning after each commit. Start permissive, grow strict when ready.

```mermaid
flowchart LR
    You -->|git add| cpm
    cpm -->|git push| Remote

    subgraph cpm [" "]
        direction LR
        A[pre-commit<br/>format + secrets] --> B[pre-push<br/>lint + test] --> C[post-commit<br/>learn + score]
    end
```

## The V-model: define left, verify right

Based on [V-model](https://en.wikipedia.org/wiki/V-model_(software_development)) systems engineering. The `>` shape shows how each decision level maps to its verification counterpart.

```mermaid
flowchart LR
    V["🎯 Value"] --> A["📝 ADR"]
    A --> AC["✅ Acceptance"]
    AC --> CODE["💻 Code"]
    CODE --> UT["🔬 Unit"]
    CODE --> IT["🧬 Integration"]
    CODE --> E2E["🔗 E2E"]
    CODE --> REG["🧪 Regression"]

    V -.-|"traced"| REG
    A -.-|"traced"| E2E
    AC -.-|"traced"| IT
```

Every level on the left (define) is traced to its counterpart on the right (verify):

| Define | Verify | Linked by |
|--------|--------|-----------|
| Value / Feature | Regression tests | Feature coverage markers |
| ADR (decision) | E2E tests | Traceability matrix |
| Acceptance criteria | Integration tests | Mutation testing |
| Code | Unit tests | Coverage + comments |

## Enforcement levels

Choose how strict cpm behaves. Start gentle, grow strict when ready.

```mermaid
graph LR
    L[🌱 learn] --> G[📋 guide] --> GU[🛡️ guard] --> E[🔒 enforce]
```

| Level | Blocks | Best for |
|-------|--------|----------|
| `learn` | Nothing | Getting started |
| `guide` | Nothing | Day-to-day development |
| `guard` | Errors only | Team projects |
| `enforce` | Errors + warnings | Production-critical |

```toml
# cpm.toml
[enforcement]
level = "guide"
```

## Install

```bash
# Recommended: Homebrew (macOS + Linux)
brew install rkristelijn/tap/cpm

# Any platform (downloads binary from GitHub Releases)
curl -fsSL https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh | bash

# From source (requires g++ with C++17)
git clone https://github.com/rkristelijn/cpm.git && cd cpm && make install
```

## Quick start

```bash
cd my-project
cpm init          # generates cpm.toml with sensible defaults
cpm check --fast  # format + build (pre-commit)
cpm check         # + lint + test (pre-push)
cpm check --full  # + coverage + sast (CI)
```

## Demo: scan a real repo

```bash
$ cpm scan ~/git/hub/console-log-json --depth 1

  Scanning (depth 1)...
  Found 1 repos

  [1/1] console-log-json                         5 findings

  Scan Report (1 repos)
  ─────────────────────────────────────────────
  Errors: 1 | Warnings: 4

$ cpm findings console-log-json
  error    node-eol              Node.js 14 is EOL — upgrade to 20+
  warning  unpinned-deps         Dependencies use ^ or ~
  warning  typescript-eol        TypeScript 4.x is EOL — upgrade to 5+
  warning  no-contributing       No CONTRIBUTING.md
  warning  no-agent-config       No AI agent config
```

No setup needed. No config. Point it at code and get actionable findings.

## Commands

| Command | Description |
|---------|-------------|
| `cpm init` | Create cpm.toml + .editorconfig + SECURITY.md + templates |
| `cpm check [--fast\|--full]` | Run quality gate (tiered) |
| `cpm score` | Show maturity score (0-100) + badge |
| `cpm scan <path>` | Scan repos for quality metrics |
| `cpm findings [repo]` | Query findings (--learn, --compliance, --junit) |
| `cpm sbom` | Generate Software Bill of Materials |
| `cpm lint` | Run all lint checks |
| `cpm format` | Auto-format all files |
| `cpm build` | Build the project |
| `cpm run` | Build and run |
| `cpm test` | Run tests |
| `cpm coverage` | Build with coverage and report |
| `cpm new <name>` | Create a new project |
| `cpm new test <name>` | Add a test file |
| `cpm new module <name>` | Add a module (cpp + hpp) |
| `cpm install` | Install tools from cpm.toml |
| `cpm eject` | Generate Makefile + CMakeLists.txt + configs |
| `cpm hook` / `unhook` | Install/remove git hooks |
| `cpm bump <major\|minor\|patch>` | Bump version in cpm.toml |
| `cpm get [key]` | Show config |
| `cpm set <key> <val>` | Update config |
| `cpm audit` | Check tool versions |
| `cpm tools` | Show installed tool versions |

## Quality checks (built-in)

58 checks across security, quality, supply chain, docs, and compliance:

| Category | Checks |
|----------|--------|
| Security | secrets, OWASP top 10, weak crypto, PII detection, env config, dangerous patterns |
| Architecture | circular deps, deep nesting, fan-out, infra coupling, dead code, mock-boundary |
| Quality | file size, complexity, comments, shadow variables, slop detection, test-to-code ratio |
| Dependencies | lockfile, version pins, audit (7 langs), license, outdated, runtime EOL |
| Supply Chain | lockfile integrity, pinned GitHub Actions, vendor lock-in |
| Web | framework misuse (React/Next/Nest/Angular), CORS, debug mode |
| Accessibility | WCAG violations, inclusivity (35 terms), unicode |
| Docs | prose lint (vale), spelling (cspell), inclusivity (alex), broken links (lychee) |
| DevOps | Makefile best practices, CI pipeline, .editorconfig, SECURITY.md, templates |
| Git Health | lottery factor, churn hotspots, large commits, stale repos |
| Compliance | ISO 27001, ISO 27701, ISO 9126, GDPR, DORA, NIST 800-53, NIS2, OWASP, WCAG, SOC 2, PCI DSS, CMMI, CE+ |

Language-specific checks:

| Language | Checks |
|----------|--------|
| C++ | format, cppcheck, clang-tidy, complexity, comments, docs |
| C# | audit, outdated, license |
| Dart/Flutter | analyze, pub outdated |
| Go | vulncheck, outdated, license, version EOL |
| Java | OWASP audit, license, outdated, Spring Boot EOL |
| PHP | audit, outdated, EOL |
| Python | audit, outdated, license, ruff, EOL, version constraint, formatter |
| Ruby | bundle-audit, outdated, license |
| Rust | cargo-audit, outdated, license, edition, unsafe detection |
| Terraform | tflint, tfsec/trivy, lockfile, version |
| TypeScript/JS | audit, outdated, license, eslint, EOL, framework misuse |

## Design principles

- **Zero friction** — works without config, without committing anything
- **One binary** — no runtime dependencies
- **Fast** — checks run in parallel, pre-commit < 5s
- **[Shift left](https://en.wikipedia.org/wiki/Shift-left_testing)** — fail fast, fail smart, fail at your level
- **Learn don't police** — every finding explains why and how to fix

See [ADR-013](docs/adrs/adr-013-product-positioning.md) for the full philosophy and [ADR-020](docs/adrs/adr-020-product-vision.md) for the product vision.

## [License](LICENSE)

MIT
