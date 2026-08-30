---
summary: Scoring system for repository technology choices, tooling, and best practices across 10 languages
status: partially-implemented
---

# ADR-018: Language Framework Scoring System

## Context

cpm (Compliance/Prompt Manager) needs a systematic way to score repositories based on their technology choices, tooling maturity, and adherence to best practices. This ADR defines a comprehensive scoring framework that evaluates repositories across 10 major language ecosystems, providing a maturity score that maps to actionable quality levels.

The scoring system must be:

- **Fast**: Based on file system checks (stat/fread) without executing tools
- **Language-aware**: Recognize framework hierarchies and deprecated patterns per language
- **Actionable**: Map scores to specific improvement recommendations
- **Comprehensive**: Cover all major languages and IaC tools

## Decision

Implement a multi-dimensional scoring system with the following components:

### Scoring Dimensions

| Dimension | Max Points | Description |
|-----------|------------|-------------|
| Framework Maturity | 25 | Primary framework choice and version currency |
| Testing Coverage | 20 | Test framework presence and variety |
| Dev Environment | 15 | Local setup reproducibility |
| Security Tooling | 15 | Security scanning and hardening |
| Architecture Quality | 15 | Code organization patterns |
| Documentation | 10 | Documentation completeness |
| **Total** | **100** | |

## Language-Specific Framework Maturity Scoring

### TypeScript/JavaScript (Node.js)

| Framework | Score | Notes |
|-----------|-------|-------|
| NestJS | 25 | Full-stack opinionated framework |
| Next.js / Nuxt | 22 | React/Vue meta-framework |
| Fastify | 18 | High-performance alternative to Express |
| Express | 15 | De facto standard, minimal |
| raw Node.js | 10 | No framework |
| **Deprecated** | **-10** | Hapi, Sails, Kraken |

**Version Requirements**:

- Node.js >= 20: +5 points
- Node.js 18-19: +2 points
- Node.js < 18: -5 points

**Package Manager**:

- pnpm: +3 points (workspace support)
- yarn (v2+): +2 points
- npm: +1 point

**Module System**:

- ESM (type: module): +5 points
- CommonJS: 0 points
- CommonJS without ESM migration path: -5 points

### Java

| Framework | Score | Notes |
|-----------|-------|-------|
| Spring Boot 3.x | 25 | Industry standard, full-featured |
| Quarkus | 22 | Cloud-native, fast startup |
| Micronaut | 20 | Compile-time DI, low footprint |
| Helidon | 18 | Oracle's microframework |
| raw Java EE/Jakarta | 15 | Standard annotations |
| raw Java (no framework) | 8 | Servlets only |

**Version Requirements**:

- Java 21: +5 points
- Java 17-20: +3 points
- Java 11-16: +1 point
- Java < 11: -10 points

**Build Tool**:

- Gradle (Kotlin DSL): +3 points
- Maven: +2 points
- Ant: -5 points

### Python

| Framework | Score | Notes |
|-----------|-------|-------|
| FastAPI | 25 | Modern, async-first, type validation |
| Django (with Django Ninja) | 23 | Full-stack with API support |
| Django REST Framework | 21 | Mature REST framework |
| Flask (with extensions) | 15 | Lightweight, explicit |
| raw Flask | 12 | Minimal Flask |
| raw Python | 8 | No web framework |

**Version Requirements**:

- Python 3.12+: +5 points
- Python 3.10-3.11: +3 points
- Python 3.8-3.9: +1 point
- Python 2.x: -25 points (immediate fail)

**Packaging**:

- pyproject.toml: +5 points
- setup.py + pyproject.toml: +2 points
- setup.py only: -3 points
- No packaging file: -5 points

### C/C++

| Framework | Score | Notes |
|-----------|-------|-------|
| CMake + Conan/vcpkg | 22 | Modern C++ ecosystem |
| CMake only | 18 | Standard build system |
| Meson | 17 | Modern, Python-like |
| raw Make | 12 | Legacy but functional |
| Autotools | 10 | Legacy Unix build |
| No build system | 5 | Ad-hoc compilation |

**C++ Standard**:

- C++23: +5 points
- C++20: +4 points
- C++17: +3 points
- C++14: +1 point
- C++11: 0 points
- C++03 or earlier: -10 points

**C Standard**:

- C23/C17: +3 points
- C11: +1 point
- C99: 0 points
- C89: -5 points

### Go

| Framework | Score | Notes |
|-----------|-------|-------|
| Standard library + go-chi/gin | 20 | Idiomatic Go |
| Buffalo | 15 | Full-stack Rails-like |
| raw Go | 12 | Standard library only |

**Go Version**:

- Go 1.22+: +5 points
- Go 1.20-1.21: +3 points
- Go 1.18-1.19: +1 point
- Go < 1.18: -5 points

**Module Management**:

- go.mod with proper versioning: +5 points
- go.mod with replace directives: +2 points
- GOPATH mode: -10 points

### Rust

| Framework | Score | Notes |
|-----------|-------|-------|
| Axum + Tokio | 22 | Modern async stack |
| Actix-web | 20 | High-performance |
| Rocket | 18 | Developer-friendly |
| warp | 17 | Minimal, composable |
| raw Iron/Hyper | 12 | Low-level |
| Standard library only | 10 | No web framework |

**Edition**:

- 2024: +5 points
- 2021: +4 points
- 2018: +2 points
- 2015: -5 points

**Cargo Features**:

- Cargo.lock committed: +3 points
- workspace members: +2 points
- Cargo.toml with [dev-dependencies]: +1 point

### PHP

| Framework | Score | Notes |
|-----------|-------|-------|
| Laravel 11.x | 25 | Full-stack modern PHP |
| Symfony 7.x | 23 | Enterprise-grade |
| Laravel 10.x | 20 | Stable modern Laravel |
| Symfony 6.x | 18 | Stable Symfony |
| Slim | 15 | Microframework |
| raw PHP | 8 | No framework |

**Version Requirements**:

- PHP 8.3+: +5 points
- PHP 8.2: +3 points
- PHP 8.0-8.1: +1 point
- PHP 7.x: -10 points
- PHP < 7: -25 points

**Package Management**:

- Composer with composer.lock: +5 points
- Composer without lock: +2 points
- No Composer: -10 points

### C#/.NET

| Framework | Score | Notes |
|-----------|-------|-------|
| ASP.NET Core 8+ | 25 | Modern cross-platform |
| ABP Framework | 22 | Full-stack opinionated |
| raw ASP.NET Core | 18 | Minimal API or MVC |
| .NET Framework 4.8 | 10 | Legacy Windows-only |
| raw .NET Framework | 5 | Web Forms/WCF |

**SDK Style**:

- SDK-style project (.NET Core/5+): +5 points
- Old-style .csproj: -3 points

**Language Version**:

- C# 12: +3 points
- C# 10-11: +2 points
- C# 9: +1 point
- C# < 9: -5 points

### Terraform/Infrastructure as Code

| Tool | Score | Notes |
|------|-------|-------|
| Terraform + Terratest/Pulumi | 22 | IaC with testing |
| Terraform + tfsec/checkov | 18 | IaC with scanning |
| Terraform (vanilla) | 15 | Basic IaC |
| Pulumi | 18 | Programmatic IaC |
| CloudFormation | 12 | AWS-specific |
| Ansible | 15 | Configuration management |
| Helm | 12 | Kubernetes packaging |

**Version Pinning**:

- .terraform-version: +3 points
- required_version constraint: +2 points
- No version constraint: -3 points

**State Management**:

- Remote state (S3/GCS): +3 points
- State locking enabled: +2 points
- Local state: 0 points

### Shell/Bash

| Pattern | Score | Notes |
|---------|-------|-------|
| ShellCheck compliant | 15 | Linted, portable |
| POSIX-compliant | 12 | Works on sh |
| Bash-specific | 8 | Requires bash |
| No shellcheck config | -3 | Not linted |

**Shell Version**:

- shebang with version: +2 points
- No hardcoded paths: +2 points
- set -euo pipefail: +3 points

## Testing Framework Scoring

### Unit Testing (Max 8 points)

| Language | Frameworks | Points |
|----------|------------|--------|
| TypeScript | Jest, Vitest | 8 |
| TypeScript | Mocha, Jasmine | 5 |
| Java | JUnit 5, TestNG | 8 |
| Java | JUnit 4 | 5 |
| Python | pytest | 8 |
| Python | unittest, nose2 | 5 |
| Go | testing package | 6 |
| Rust | cargo test, rstest | 6 |
| PHP | PHPUnit | 8 |
| C/C++ | Catch2, doctest | 6 |
| C# | xUnit, NUnit | 8 |
| Shell | bats, shunit2 | 5 |

### Integration Testing (Max 6 points)

| Language | Frameworks | Points |
|----------|------------|--------|
| TypeScript | Supertest, MSW | 6 |
| Java | TestContainers, WireMock | 6 |
| Python | pytest-asyncio, requests-mock | 5 |
| Go | testcontainers-go, dockertest | 5 |
| PHP | Pest, Behat | 5 |
| All | Docker Compose for tests | +3 |

### E2E Testing (Max 4 points)

| Framework | Points |
|-----------|--------|
| Playwright | 4 |
| Cypress | 3 |
| Selenium | 2 |
| No E2E tests | 0 |

### Mutation Testing (Max 2 points)

| Framework | Points |
|-----------|--------|
| Stryker (JS), Pitest (Java), mutmut (Python) | 2 |
| No mutation testing | 0 |

### Test Coverage Requirements

| Coverage | Points |
|----------|--------|
| >= 80% | 4 |
| 60-79% | 3 |
| 40-59% | 2 |
| 20-39% | 1 |
| < 20% | 0 |

## Monorepo Tool Scoring (Max 5 points)

| Tool | Points | Language |
|------|--------|----------|
| Nx | 5 | TypeScript, JS, Java, Go, Rust |
| Turborepo | 5 | TypeScript, JS |
| Bazel | 5 | Multi-language |
| Pants | 5 | Python, Java, Go, Rust |
| Lerna | 3 | TypeScript, JS |
| Yarn Workspaces | 2 | TypeScript, JS |
| npm Workspaces | 1 | TypeScript, JS |
| Go workspaces (go.work) | 2 | Go |

## Development Environment Scoring (Max 15 points)

### Containerization (Max 6 points)

| File | Points | Check Type |
|------|--------|------------|
| docker-compose.yml | 4 | stat |
| Dockerfile | 2 | stat |
| .dockerignore | 1 | stat |

### Reproducible Environments (Max 4 points)

| File | Points | Check Type |
|------|--------|------------|
| flake.nix | 4 | stat |
| devbox.json | 3 | stat |
| .devcontainer/ | 3 | stat |
| .env.example | 2 | fread |

### Build Automation (Max 5 points)

| File | Points | Check Type |
|------|--------|------------|
| Makefile with setup target | 5 | fread |
| Makefile without setup | 2 | fread |
| justfile | 3 | stat |
| taskfile.yml | 3 | stat |
| package.json with scripts | 2 | fread |

## Security Tooling Scoring (Max 15 points)

### Secret Scanning (Max 4 points)

| File | Points | Check Type |
|------|--------|------------|
| .gitleaks.toml | 3 | stat |
| .semgrepignore | 2 | stat |
| trufflehog config | 2 | stat |
| pre-commit hooks | 2 | stat |

### Dependency Scanning (Max 4 points)

| File | Points | Check Type |
|------|--------|------------|
| .snyk | 3 | stat |
| dependabot.yml | 3 | stat |
| renovate.json | 2 | stat |
| safety.toml | 2 | stat |

### Security Headers/Config (Max 4 points)

| File | Points | Check Type |
|------|--------|------------|
| helmet config (TS) | 3 | fread |
| CORS config | 2 | fread |
| security.txt | 2 | stat |
| .owasp/ | 2 | stat |

### SAST/DAST (Max 3 points)

| File | Points | Check Type |
|------|--------|------------|
| .bandit (Python) | 2 | stat |
| semgrep.yml | 3 | stat |
| checkov.yml | 2 | stat |
| owasp-dependency-check | 2 | stat |

## Deprecated/Outdated Indicators (Negative Scoring)

### Immediate Failures (-25 points each)

| Indicator | Language | Check |
|-----------|----------|-------|
| Python 2 syntax | Python | fread: python2 in shebang |
| PHP < 8.0 | PHP | fread: version in composer.json |
| Java < 11 | Java | fread: source/target in pom.xml |
| TSLint config | TypeScript | stat: tslint.json |

### Major Penalties (-10 points each)

| Indicator | Language | Check |
|-----------|----------|-------|
| Mocha without Vitest | TypeScript | fread: package.json |
| CommonJS only | TypeScript | fread: no type: module |
| Node < 18 | TypeScript | fread: engines in package.json |
| setup.py only | Python | stat: no pyproject.toml |
| Struts 1/Tapestry | Java | fread: dependencies |
| .NET Framework | C# | fread: TargetFramework |
| GOPATH mode | Go | stat: no go.mod |

### Minor Penalties (-3 points each)

| Indicator | Language | Check |
|-----------|----------|-------|
| package-lock.json missing | TypeScript | stat |
| yarn.lock without pnpm-lock | TypeScript | stat |
| Cargo.lock missing | Rust | stat |
| composer.lock missing | PHP | stat |
| go.sum missing | Go | stat |
| No lock file | Any | stat |

## Architecture Quality Scoring (Max 15 points)

### Directory Structure (Max 6 points)

| Pattern | Points | Check Type |
|---------|--------|------------|
| src/ directory exists | 2 | stat |
| Not everything in root | 2 | stat |
| Clear package structure | 2 | stat |

### Separation of Concerns (Max 5 points)

| Pattern | Points | Check Type |
|---------|--------|------------|
| controllers/ or handlers/ | 2 | stat |
| services/ or usecases/ | 2 | stat |
| models/ or entities/ | 1 | stat |
| repositories/ or daos/ | 1 | stat |

### Configuration (Max 2 points)

| Pattern | Points | Check Type |
|---------|--------|------------|
| .env.example or config/ | 2 | stat |
| No hardcoded config | 1 | fread |

### Architectural Patterns (Max 2 points)

| Pattern | Points | Check Type |
|---------|--------|------------|
| Hexagonal: adapters/, ports/, domain/ | 2 | stat |
| DDD: bounded contexts as dirs | 2 | stat |
| Clean Architecture layers | 1 | stat |

## Documentation Scoring (Max 10 points)

| Item | Points | Check Type |
|------|--------|------------|
| docs/ directory exists | 2 | stat |
| README.md | 2 | stat |
| CONTRIBUTING.md | 1 | stat |
| CODE_OF_CONDUCT.md | 1 | stat |
| LICENSE file | 1 | stat |
| CHANGELOG.md | 1 | stat |
| API docs (openapi.json, swagger/) | 2 | stat |
| ADR directory | 1 | stat |
| Architecture decision records | 1 | fread |

## Fast File Check Reference

### stat() Only Checks (Immediate existence check)

| File Pattern | Meaning | Scoring |
|--------------|---------|---------|
| docker-compose.yml | Containerized dev | +4 |
| Dockerfile | Containerized build | +2 |
| .devcontainer/ | VS Code dev container | +3 |
| flake.nix | Nix reproducible env | +4 |
| devbox.json | Devbox reproducible env | +3 |
| Makefile | Build automation | +2-5 |
| justfile | Build automation | +3 |
| taskfile.yml | Build automation | +3 |
| package.json | Node project | +1 |
| go.mod | Go module | +5 |
| pyproject.toml | Python package | +5 |
| pom.xml / build.gradle | Java build | +2 |
| Cargo.toml | Rust project | +3 |
| composer.json | PHP project | +2 |
| *.sln / *.csproj | .NET project | +2 |
| terraform.tfstate | Terraform state | +1 |
| .gitleaks.toml | Secret scanning | +3 |
| .semgrepignore | SAST config | +2 |
| .snyk | Dependency scanning | +3 |
| dependabot.yml | Auto updates | +3 |
| docs/ | Documentation dir | +2 |
| openapi.json / swagger/ | API docs | +2 |
| ADR directory | Architecture docs | +1 |

### fread() Required Checks (Content inspection)

| File | Content to Check | Scoring |
|------|------------------|---------|
| package.json | type: module, engines, dependencies | ESM: +5, Node 20+: +5 |
| pyproject.toml | [build-system], requires-python | Python 3.12+: +5 |
| pom.xml / build.gradle | source/target version | Java 21: +5 |
| go.mod | go directive | Go 1.22+: +5 |
| composer.json | php version | PHP 8.3+: +5 |
| Dockerfile | FROM image version | Base image recent: +2 |
| Makefile | setup target | setup target: +5 |
| tsconfig.json | target, module | ESM target: +3 |
| Cargo.toml | edition | Rust 2024: +5 |
| .env.example | Required vars | Config externalized: +2 |

## Scoring Tables Summary

### Framework Maturity (25 points max)

| Category | Score Range |
|----------|-------------|
| Modern, full-stack framework | 20-25 |
| Established microframework | 15-19 |
| Minimal framework | 10-14 |
| Raw language | 5-9 |
| Deprecated framework | -10 to 0 |

### Testing (20 points max)

| Category | Score Range |
|----------|-------------|
| Full test pyramid + mutation | 18-20 |
| Unit + integration + E2E | 14-17 |
| Unit + integration | 10-13 |
| Unit only | 5-9 |
| No tests | 0 |

### Dev Environment (15 points max)

| Category | Score Range |
|----------|-------------|
| Container + reproducible + Makefile | 13-15 |
| Container + reproducible | 10-12 |
| Container only | 6-9 |
| Makefile only | 4-6 |
| Manual setup | 0-3 |

### Security (15 points max)

| Category | Score Range |
|----------|-------------|
| Secret + dependency + SAST | 13-15 |
| Two security tools | 9-12 |
| One security tool | 5-8 |
| Basic config | 2-4 |
| No security tooling | 0-1 |

### Architecture (15 points max)

| Category | Score Range |
|----------|-------------|
| Clean structure + patterns | 13-15 |
| Clear separation | 10-12 |
| Basic src/ structure | 6-9 |
| Monolithic root | 2-5 |
| No structure | 0-1 |

### Documentation (10 points max)

| Category | Score Range |
|----------|-------------|
| Full docs + API + ADRs | 9-10 |
| Docs + README + LICENSE | 6-8 |
| README + LICENSE | 3-5 |
| README only | 1-2 |
| No documentation | 0 |

## Maturity Level Mapping

| Total Score | Level | Description |
|-------------|-------|-------------|
| 85-100 | A+ | Excellent - Industry best practices |
| 70-84 | A | Good - Modern stack, well-maintained |
| 55-69 | B | Acceptable - Functional but dated |
| 40-54 | C | Needs improvement - Technical debt |
| 25-39 | D | Poor - Significant issues |
| 0-24 | F | Critical - Major problems |

### Level A+ Requirements

- Framework: Latest stable version (within 6 months)
- Testing: 80%+ coverage, mutation testing
- Security: All 4 categories present
- Architecture: Clean separation, documented patterns
- Documentation: Complete with ADRs

### Level A Requirements

- Framework: Current major version
- Testing: 60%+ coverage, E2E tests
- Security: Secret + dependency scanning
- Architecture: Clear src/ structure
- Documentation: README, LICENSE, CONTRIBUTING

### Level B Requirements

- Framework: One major version behind
- Testing: 40%+ coverage, integration tests
- Security: At least one tool
- Architecture: Basic separation
- Documentation: README + LICENSE

### Level C Requirements

- Framework: Two major versions behind
- Testing: Unit tests present
- Security: Basic config (CORS, headers)
- Architecture: src/ exists
- Documentation: README only

### Level D/F Requirements

- Deprecated frameworks present
- No testing or minimal testing
- No security tooling
- Monolithic structure
- Missing documentation

## Implementation

### Check Order (for early exit optimization)

1. **Language detection** (stat): package.json, go.mod, pyproject.toml, pom.xml, Cargo.toml, composer.json, *.csproj, *.sln, *.tf, *.sh
2. **Deprecated check** (fread): Immediate fail conditions
3. **Framework version** (fread): Framework maturity score
4. **Testing presence** (stat): jest.config, pytest.ini, go test, etc.
5. **Security tooling** (stat): .gitleaks.toml, .snyk, etc.
6. **Architecture** (stat): Directory structure
7. **Documentation** (stat): docs/, README, etc.
8. **Dev environment** (stat): docker-compose, Makefile, etc.

### Example Scoring Output

```text
Repository: my-awesome-api
Language: TypeScript (Node.js)
Framework: NestJS (22 pts)
Version: Node 20 (5 pts) + ESM (5 pts) = 10 pts
Testing: Jest (8) + Supertest (4) + Playwright (4) = 16 pts
Monorepo: Turborepo (5 pts)
DevEnv: docker-compose (4) + .env.example (2) = 6 pts
Security: .gitleaks.toml (3) + semgrep.yml (3) = 6 pts
Architecture: src/ (2) + controllers/services/models (5) = 7 pts
Docs: README (2) + LICENSE (1) + CHANGELOG (1) = 4 pts

TOTAL: 22 + 10 + 16 + 5 + 6 + 6 + 7 + 4 = 76
Maturity Level: A (Good)
```

## Consequences

- Provides objective, reproducible scoring for any repository
- Enables comparison across repositories and teams
- Identifies specific improvement areas
- Supports automated CI/CD quality gates
- Aligns with ADR-012 maturity framework research

## References

- [ADR-012: Maturity Framework Research](./adr-012-maturity-framework-research.md)
- [OpenSSF Scorecard](https://scorecard.dev/)
- [Test Pyramid](https://martinfowler.com/bliki/TestPyramid.html)
- [12-Factor App](https://12factor.net/)
- [OWASP SAMM](https://owaspsamm.org/)
