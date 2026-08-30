# ADR-141: Language Coverage Matrix and Supply Chain Security

*Status*: partially-implemented · *Date*: 2026-05-20 · *Author*: kiro

## Context

cpm aims to be the universal quality layer. After implementing checks for 14/20 top languages, a gap analysis reveals inconsistent coverage depth per language. Additionally, supply chain attacks (SolarWinds, Log4Shell, xz-utils) make dependency security non-optional.

## Problem

Not every language ecosystem has the same tooling maturity:

| Ecosystem | Package manager | Audit tool | License tool | Outdated tool | Lockfile |
|-----------|----------------|-----------|--------------|---------------|----------|
| npm/JS | npm/pnpm/yarn | `npm audit` | `license-checker` | `npm outdated` | package-lock.json |
| Python | pip/poetry | `pip-audit` | `pip-licenses` | `pip list --outdated` | poetry.lock |
| Go | go mod | `govulncheck` | `go-licenses` | `go list -m -u all` | go.sum |
| Rust | cargo | `cargo-audit` | `cargo-license` | `cargo outdated` | Cargo.lock |
| Java | maven/gradle | `mvn owasp:check` | `mvn license:check` | `mvn versions:display-dependency-updates` | ❌ (no lockfile standard) |
| C# | nuget | `dotnet list --vulnerable` | `dotnet-project-licenses` | `dotnet list --outdated` | packages.lock.json |
| PHP | composer | `composer audit` | ❌ (manual) | `composer outdated` | composer.lock |
| Ruby | bundler | `bundle-audit` | `license_finder` | `bundle outdated` | Gemfile.lock |
| Dart | pub | ❌ | ❌ | `dart pub outdated` | pubspec.lock |
| C/C++ | ❌ (no standard) | ❌ | N/A | N/A | N/A |
| Terraform | terraform | `trivy config` | N/A | `tflint` | .terraform.lock.hcl |

### Why some ecosystems lack tools

1. **C/C++**: No standard package manager → no dependency graph → no audit possible
2. **Dart**: Young ecosystem, security tooling still maturing
3. **Java**: Has tools but no standard lockfile (maven doesn't lock by default)
4. **PHP license**: No single standard tool (fragmented)

### Supply chain attack vectors

| Vector | Example | cpm coverage |
|--------|---------|-------------|
| Known CVE in dependency | Log4Shell | ✅ audit checks |
| Typosquatting | `crossenv` vs `cross-env` | ❌ not detected |
| Maintainer takeover | `event-stream` | ❌ not detected |
| Build-time injection | SolarWinds | ❌ out of scope (needs runtime) |
| Lockfile manipulation | `package-lock.json` poisoning | ❌ not detected |
| Unpinned dependencies | `^` allows malicious minor | ✅ `unpinned-deps` check |
| No lockfile | Reproducibility broken | ✅ `no-lockfile` check |
| Stale dependencies | Unmaintained = unpatched | ✅ outdated checks |
| Excessive permissions | npm postinstall scripts | ❌ not detected |

## Decision

### Phase 1: Fill the matrix (immediate)

Add missing checks where tools exist:

```text
Python:  pip list --outdated, pip-licenses, ruff
Java:    mvn versions:display-dependency-updates
Go:      go list -m -u all, go-licenses
Rust:    cargo outdated, cargo-license
Ruby:    license_finder
PHP:     composer outdated
```

### Phase 2: Supply chain hardening

Add checks that detect supply chain risks:

| Check | What it detects | How |
|-------|----------------|-----|
| `deps-lockfile-integrity` | Lockfile out of sync with manifest | Compare package.json vs lock |
| `deps-install-scripts` | Suspicious postinstall scripts | Parse package.json scripts |
| `deps-new-maintainer` | Recent maintainer change on critical deps | npm info (API) |
| `deps-typosquat` | Package names similar to popular ones | Levenshtein distance |
| `deps-pinned-actions` | GitHub Actions using `@main` instead of SHA | grep workflows |

### Phase 3: Framework misuse expansion

| Framework | Current | Missing |
|-----------|---------|---------|
| React | EOL, hooks misuse | XSS via dangerouslySetInnerHTML |
| Next.js | EOL, headers, poweredBy | SSRF via server actions, open redirects |
| Django | EOL | DEBUG=True in prod, ALLOWED_HOSTS=* |
| Spring Boot | EOL | Actuator exposed, CSRF disabled |
| Laravel | EOL | APP_DEBUG=true, mass assignment |
| Express | EOL | No helmet, no rate limiting |
| NestJS | EOL | — |
| Angular | EOL | bypassSecurityTrust* |
| Vue | EOL | v-html XSS |
| FastAPI | — | No CORS config, no auth middleware |
| Flask | — | debug=True, secret_key hardcoded |
| Gin (Go) | — | No middleware, no input validation |
| Actix (Rust) | — | — |
| ASP.NET | — | No anti-forgery, no auth |

## Rationale

- Supply chain is the #1 attack vector in 2024-2025
- Every language with a package manager should have: audit + outdated + license
- Framework misuse checks prevent the most common deployment mistakes
- cpm's unique position: orchestrate all of this in one score

## Current Coverage (after Phase 1)

### Top 500 Scan Results (2026-05-21)

## 494 repos scanned, 2509 findings (40 errors, 2469 warnings)

### Activity & Health

| Metric | Value |
|--------|-------|
| Active (<3 months) | 399 repos (80%) |
| Recent (3-12 months) | 35 repos (7%) |
| Stale (>12 months) | 60 repos (12%) |
| Clean (0 findings) | 6 repos (1%) |

#### What % of top 500 repos miss

| What | % missing | Count |
|------|-----------|-------|
| AI agent config | 72% | 358/494 |
| SECURITY.md | 61% | 303/494 |
| .editorconfig | 47% | 234/494 |
| CONTRIBUTING.md | 43% | 217/494 |
| PR template | 35% | 175/494 |
| Unpinned deps | 30% | 151/494 |
| Tests (detected) | 29% | 144/494 |
| Issue templates | 20% | 103/494 |
| CI pipeline | 20% | 100/494 |
| Lockfile | 15% | 79/494 |
| Stale | 11% | 57/494 |
| .gitignore | 10% | 54/494 |

#### Language distribution

| Language | Repos | cpm support |
|----------|-------|-------------|
| Python | 115 | audit, outdated, license, ruff, EOL |
| TypeScript | 108 | npm audit/outdated/license, eslint, EOL |
| JavaScript | 69 | same as TS |
| Go | 34 | govulncheck, outdated, license |
| Rust | 30 | cargo-audit, outdated, license |
| C/C++ | 42 | clang-format, cppcheck, clang-tidy |
| Java | 19 | mvn audit, license, outdated, EOL |
| Ruby | 9 | bundle-audit, outdated, license |
| Kotlin | 7 | via Java/Gradle |
| Dart | 6 | dart analyze, pub outdated |
| C# | 6 | dotnet audit, outdated |
| PHP | 4 | composer audit, outdated |

#### File composition (averages)

| Type | Avg files | % of total |
|------|-----------|-----------|
| Config (.yml, .json, .toml, dotfiles) | 4,653 | 33% |
| Code | 1,957 | 14% |
| Docs (.md) | 398 | 2% |
| Total | 13,825 | 100% |

#### Repo size distribution

| Size | Count | % |
|------|-------|---|
| Small (<100 files) | 95 | 19% |
| Medium (100-1k) | 174 | 35% |
| Large (1k-10k) | 175 | 35% |
| Huge (>10k) | 50 | 10% |

#### Maturity distribution

| Level | Repos | % |
|-------|-------|---|
| Level 4 (optimized) | 6 | 1% |
| Level 3 (measured) | 74 | 15% |
| Level 2 (defined) | 146 | 30% |
| Level 1 (managed) | 231 | 47% |
| Level 0 (initial) | 37 | 7% |

### Coverage Matrix (after Phase 1)

| Check type | Python | JS/TS | Java | C# | Go | Rust | C/C++ | PHP | Ruby | Dart | Terraform |
|-----------|--------|-------|------|----|----|------|-------|-----|------|------|----|
| **Vuln audit** | pip-audit | npm audit | mvn owasp | dotnet vuln | govulncheck | cargo-audit | — | composer audit | bundle-audit | — | trivy/tfsec |
| **Outdated** | pip outdated | npm outdated | mvn versions | dotnet outdated | go list -u | cargo outdated | — | composer outdated | bundle outdated | dart pub outdated | — |
| **License** | pip-licenses | license-checker | mvn license | dotnet-licenses | go-licenses | cargo-license | — | — | license_finder | — | — |
| **Lint/format** | ruff | eslint | — | — | — | — | clang-format/tidy | — | — | dart analyze | tflint |
| **SAST** | semgrep | semgrep | semgrep | semgrep | semgrep | semgrep | semgrep+cppcheck | semgrep | semgrep | — | tfsec/trivy |
| **EOL/runtime** | .python-version | .nvmrc | pom.xml | — | — | — | — | composer.json | — | — | versions.tf |
| **Lockfile** | poetry.lock | package-lock | — | packages.lock | go.sum | Cargo.lock | N/A | composer.lock | Gemfile.lock | pubspec.lock | .terraform.lock |
| **Supply chain** | — | lockfile-sync | — | — | — | — | — | — | — | — | — |

## Coverage: 42/55 cells filled (76%)

Cells marked — either have no standard tool available or are not applicable.

## Consequences

- ~20 new checks to implement
- Supply chain checks require network access (API calls) → only in `--full` mode
- Framework misuse checks are native (pattern matching, no external tools)
- Coverage target: 5 check types × 11 ecosystems = 55 cells, currently 42 filled (76%)
- After Phase 2+3: 50/55 (91%)
