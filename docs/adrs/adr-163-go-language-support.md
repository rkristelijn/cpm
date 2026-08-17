# ADR-163: Go Language Support

**Status:** Accepted  
**Date:** 2026-08-17  
**Author:** Remi Kristelijn

## Context

Go is increasingly used in our infrastructure tooling (e.g. `gitlab-management` governance engine, Terraform providers, CLI tools). cpm already detects Go projects via `go.mod` and performs basic checks (lockfile, outdated deps, license scan), but lacks dedicated security and quality rules comparable to what we have for C++, JavaScript, and Python.

The Go ecosystem has mature static analysis tools (gosec, staticcheck, govulncheck, golangci-lint) that catch issues our regex-based rules cannot. We need a strategy for integrating both:

1. **cpm-native rules** (fast, zero-dependency, regex-based)
2. **External tool orchestration** (deeper analysis, requires Go toolchain)

## Decision

### Phase 1: Native Rules (implemented)

Add regex-based Go rules to `rules/go/` using the pluggable rule engine (ADR-145):

**Security (GO-SEC-010 to GO-SEC-019):**
- Hardcoded credentials, SQL/command injection, path traversal, SSRF
- Insecure TLS, weak crypto, unsafe package
- HTTP without timeout, overly permissive file permissions

**Quality (GO-QUAL-010 to GO-QUAL-020):**
- panic/os.Exit/log.Fatal in library code
- init() side effects, ignored errors, unwrapped errors
- time.Sleep, empty interface overuse, global mutable state
- Hardcoded addresses, defer in loop

These rules are fast (~10ms for a full project), require no external dependencies, and catch the most common issues.

### Phase 2: External Tool Integration (planned)

Orchestrate Go-specific tools when available on the system:

| Tool | Install method | Purpose |
|------|---------------|---------|
| `gosec` | `go install github.com/securego/gosec/v2/cmd/gosec@latest` | AST+SSA security analysis, taint tracking |
| `govulncheck` | `go install golang.org/x/vuln/cmd/govulncheck@latest` | Known vulnerability detection in dependencies |
| `staticcheck` | `go install honnef.co/go/tools/cmd/staticcheck@latest` | Correctness, performance, style |
| `golangci-lint` | `brew install golangci-lint` | Meta-linter (aggregates 100+ linters) |

**Integration pattern:**
- Tools are optional — cpm detects if they're installed via `command -v`
- If present, cpm runs them and normalizes output to cpm finding format
- If absent, cpm prints install hint and continues with native rules only
- `cpm.toml` controls which tools are enabled:

```toml
[tools]
gosec = "2.21"
govulncheck = "latest"
staticcheck = "2024.1"

[checks]
code-go-security-scan = true      # gosec
code-go-vulnerability-scan = true  # govulncheck
code-go-quality-lint = true        # staticcheck
```

### Phase 3: Setup Integration (planned)

Extend `setup.cpp` PkgMap with a `go_install` field:

```cpp
typedef struct {
  const char* tool;
  const char* brew;
  const char* apt;
  const char* apk;
  const char* winget;
  const char* go_install;  // "go install <path>@<version>"
} PkgMap;
```

Fallback order:
1. `brew install <tool>` (if available via brew, e.g. golangci-lint)
2. `go install <path>@<version>` (if Go toolchain available)
3. Skip with hint message

## Consequences

- Go projects get immediate value from native rules (Phase 1 — done)
- Deeper analysis available when tools are installed (Phase 2)
- No hard dependency on Go toolchain for basic checks
- Rule engine remains fast and portable
- External tools add ~5-30s to scan time depending on project size

## References

- [gosec rules](https://github.com/securego/gosec/blob/master/RULES.md)
- [govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck)
- [staticcheck checks](https://staticcheck.dev/docs/checks/)
- [golangci-lint linters](https://golangci-lint.run/usage/linters/)
- ADR-145: Pluggable Rule Engine
