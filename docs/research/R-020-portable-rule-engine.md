# Static Analysis & Linting Tool Architecture Research

**Date:** 2026-07-21  
**Purpose:** Inform the architecture of `cpm` (code project maturity) by studying how established static analysis and linting tools are built.

---

## 1. Tool-by-Tool Analysis

### 1.1 Gitleaks — Secret Scanning

| Aspect | Detail |
|--------|--------|
| **Core language** | Go |
| **Rule definition** | TOML configuration file. Each rule has an ID, description, regex pattern, optional entropy thresholds, keywords for pre-filtering, and allowlists. |
| **Distribution** | Single static binary. Also: Homebrew, Docker, `go install`, GitHub releases (cross-compiled for Linux/macOS/Windows/ARM). |
| **Custom rules without recompile** | Yes — provide a custom `.gitleaks.toml` via `--config` flag. Rules are purely declarative. |
| **Rule evaluation engine** | Regex + Shannon entropy analysis. Keyword pre-filter narrows candidates before regex matching. |
| **Rule bundling** | Default ruleset is embedded in the binary at compile time (a `gitleaks.toml` compiled into the Go binary). Users override or extend via external TOML files. |

**Key insight:** Gitleaks proves that regex + entropy in a single Go binary with TOML-based rules can scale to hundreds of patterns with excellent performance and zero runtime dependencies.

---

### 1.2 Semgrep — Multi-Language Static Analysis

| Aspect | Detail |
|--------|--------|
| **Core language** | OCaml (semgrep-core engine), Python (CLI wrapper/orchestration) |
| **Rule definition** | YAML files. Patterns look like source code (not regex). Supports boolean composition (`pattern-either`, `pattern-not`, `metavariable-regex`, etc.). |
| **Distribution** | Python package (`pip install semgrep`), Docker, Homebrew. The OCaml engine is bundled as a compiled binary inside the Python package. |
| **Custom rules without recompile** | Yes — write YAML rule files. No compilation needed. Rules are "code patterns" that read like the target language. Also has a community rule registry. |
| **Rule evaluation engine** | AST-based pattern matching (tree-sitter + pfff parsers). Also has "spacegrep" for generic/text-based matching where no parser exists. |
| **Rule bundling** | Separate YAML files in a rules repository (`semgrep-rules`). Registry at semgrep.dev. Rules fetched at runtime or vendored locally. |

**Key insight:** Semgrep's "patterns look like code" approach makes rule authoring accessible. The separate "spacegrep" engine for generic matching is relevant — it does grep-like matching on unstructured content.

---

### 1.3 Spectral (Stoplight) — API/JSON/YAML Linting

| Aspect | Detail |
|--------|--------|
| **Core language** | TypeScript/JavaScript |
| **Rule definition** | YAML, JSON, or JavaScript/TypeScript rulesets. Rules specify: target (JSONPath-like `given` expression), a function to run (`then`), and severity. |
| **Distribution** | npm package (`@stoplight/spectral-cli`). Also Docker. |
| **Custom rules without recompile** | Yes — create a `.spectral.yaml` (or `.js`/`.ts`) file. Custom "functions" can be written in JS/TS for complex validation logic. |
| **Rule evaluation engine** | JSONPath traversal + built-in function library (pattern, schema, truthy, enumeration, etc.). Custom functions for anything complex. |
| **Rule bundling** | Built-in rulesets (OpenAPI, AsyncAPI, Arazzo) ship with the npm package. Custom rulesets loaded from local files or URLs. Rulesets can `extend` others. |

**Key insight:** Spectral's separation of "where to look" (JSONPath) and "what to check" (function) is clean and composable. The ability to share rulesets via URLs/npm packages is a good distribution model.

---

### 1.4 Trivy — Vulnerability & Misconfiguration Scanning

| Aspect | Detail |
|--------|--------|
| **Core language** | Go |
| **Rule definition** | Vulnerability checks use a database (advisory DB). Misconfiguration checks written in Rego (OPA policy language). |
| **Distribution** | Single Go binary. Also: Homebrew, apt/yum repos, Docker, GitHub releases. |
| **Custom rules without recompile** | Yes — write custom Rego policies and pass with `--config-check` / `--policy`. |
| **Rule evaluation engine** | Rego (OPA) engine for misconfiguration. Database lookup + version comparison for vulnerabilities. Structural parsers normalize IaC formats before Rego evaluation. |
| **Rule bundling** | Built-in policies distributed as an OPA bundle via OCI registry (GHCR). Pulled and cached locally. Vulnerability DB also fetched from OCI registry. |

**Key insight:** Trivy uses OCI registries for distributing rule bundles — a modern, versioned, pull-based approach. Rego is powerful but has a steep learning curve.

---

### 1.5 golangci-lint — Go Linter Aggregator

| Aspect | Detail |
|--------|--------|
| **Core language** | Go |
| **Rule definition** | Each linter is a Go module implementing a standard interface (`go/analysis`). Configuration via `.golangci.yml` (enable/disable linters, set per-linter options). |
| **Distribution** | Single binary. Homebrew, `go install`, Docker, GitHub releases. |
| **Custom rules without recompile** | Partially — "module plugin system" allows adding custom linters, but requires rebuilding golangci-lint with CGO or using the module plugin approach (compile a custom binary). Not truly runtime-extensible. |
| **Rule evaluation engine** | Go AST (`go/analysis` framework). Each linter operates on parsed Go AST. Some linters also use type-checking information. |
| **Rule bundling** | All ~100+ linters compiled into the single binary. Configuration only enables/disables them. |

**Key insight:** golangci-lint shows the "aggregator" pattern — one binary wraps many linters. Downside: adding custom rules requires recompilation. This is a cautionary example.

---

### 1.6 ESLint — JavaScript Linting

| Aspect | Detail |
|--------|--------|
| **Core language** | JavaScript/Node.js |
| **Rule definition** | Rules are JavaScript modules that receive AST nodes via a visitor pattern. Configuration via `eslint.config.js` (flat config) or legacy `.eslintrc`. |
| **Distribution** | npm package. |
| **Custom rules without recompile** | Yes — write a JS module exporting a `create()` function. Package as an npm plugin or use inline/local rules. |
| **Rule evaluation engine** | AST-based (Espree parser for JS, extensible to other parsers like `@typescript-eslint/parser`). Rules use CSS-like AST selectors. |
| **Rule bundling** | Core rules ship with the npm package. Community rules distributed as npm packages (plugins). Shareable configs also via npm. |

**Key insight:** ESLint's plugin ecosystem thrives because the barrier to entry is low (write a JS function) and distribution is trivial (npm publish). The "visitor pattern on AST" model is well-understood by JS developers.

---

### 1.7 Checkov — IaC Scanning

| Aspect | Detail |
|--------|--------|
| **Core language** | Python |
| **Rule definition** | Python classes (inherit from `BaseCheck`) or YAML policy definitions. Each check targets specific resource types and evaluates attribute conditions. |
| **Distribution** | pip package, Docker, Homebrew (via pipx). |
| **Custom rules without recompile** | Yes — write Python check classes or YAML policy files. Load via `--external-checks-dir` or `--external-checks-git`. |
| **Rule evaluation engine** | Graph-based scanning. Parses HCL/CloudFormation/K8s into an internal resource graph, then evaluates attribute conditions and cross-resource connections. |
| **Rule bundling** | ~2500+ built-in checks ship with the pip package. External checks loaded from directories or git repos. |

**Key insight:** Checkov's dual approach (Python for complex checks, YAML for simple attribute checks) is effective. YAML lowers the barrier for common patterns; Python handles complex logic.

---

### 1.8 MegaLinter — Meta-Linter

| Aspect | Detail |
|--------|--------|
| **Core language** | Python (orchestration layer) |
| **Rule definition** | MegaLinter itself doesn't define rules — it orchestrates 100+ existing linters. Each linter is described in a YAML descriptor (command, file extensions, config file names, etc.). |
| **Distribution** | Docker images (one mega image or "flavor" images per language). Also GitHub Action. |
| **Custom rules without recompile** | Add custom linters via plugin descriptors (YAML files specifying the linter's CLI interface). Individual linters retain their own configuration. |
| **Rule evaluation engine** | Delegates entirely to underlying linters. MegaLinter handles file routing, parallelism, and result aggregation. |
| **Rule bundling** | Linters are pre-installed in Docker images. Descriptor YAML files define how to invoke each one. |

**Key insight:** MegaLinter proves the "orchestrator" pattern works — but requires Docker, making it heavy for local dev use. Its descriptor YAML for defining "how to run a linter" is a useful abstraction.

---

### 1.9 SonarQube — Code Quality Platform

| Aspect | Detail |
|--------|--------|
| **Core language** | Java (server + analyzers) |
| **Rule definition** | Rules implemented as Java classes using language-specific APIs (visitor pattern on AST). Some languages support XPath 1.0 rules via web UI. |
| **Distribution** | Server application (Java WAR/Docker). Requires a running server + database. Scanners are separate CLI tools (also Java-based). |
| **Custom rules without recompile** | Partially — XPath rules can be added via web UI for some languages. Full custom rules require building a Java plugin (JAR), deploying to `extensions/plugins/`, and restarting the server. |
| **Rule evaluation engine** | Language-specific AST analyzers. Each language plugin has its own parser and visitor framework. |
| **Rule bundling** | Rules bundled in language plugins (JARs). Distributed via Marketplace or manual installation. |

**Key insight:** SonarQube is the "enterprise platform" approach — powerful but heavyweight. Not suitable as a model for a portable CLI tool. The XPath rule feature for simple cases is interesting.

---

### 1.10 PMD — Source Code Analyzer

| Aspect | Detail |
|--------|--------|
| **Core language** | Java |
| **Rule definition** | Java classes (visitor pattern) OR XPath 3.1 expressions against the AST. Rules grouped into rulesets defined in XML. |
| **Distribution** | ZIP archive (Java + shell scripts). Maven plugin. Requires JRE. |
| **Custom rules without recompile** | Yes — XPath rules can be written without any Java code (just XML rulesets). Java rules require compilation but not modifying PMD itself. |
| **Rule evaluation engine** | AST-based. Uses JavaCC and Antlr parsers. XPath queries evaluated against the AST DOM. |
| **Rule bundling** | 400+ built-in rules in XML rulesets bundled in the distribution. Custom rulesets loaded from filesystem or classpath. |

**Key insight:** PMD's XPath-on-AST approach for custom rules is powerful for AST-level analysis but requires understanding the AST structure. The dual approach (XPath for simple, Java for complex) parallels Checkov's pattern.

---

## 2. Comparison Table

| Tool | Language | Rule Format | Distribution | Custom Rules (no recompile) | Engine | Rule Storage |
|------|----------|-------------|-------------|---------------------------|--------|--------------|
| **Gitleaks** | Go | TOML | Single binary | ✅ TOML config | Regex + entropy | Embedded + external TOML |
| **Semgrep** | OCaml + Python | YAML | pip + binary | ✅ YAML files | AST + spacegrep | Separate files / registry |
| **Spectral** | TypeScript | YAML/JS/TS | npm | ✅ YAML or JS/TS | JSONPath + functions | npm packages / URLs |
| **Trivy** | Go | Rego | Single binary | ✅ Rego policies | OPA + DB lookup | OCI bundle (GHCR) |
| **golangci-lint** | Go | Go code | Single binary | ⚠️ Requires rebuild | Go AST | Compiled-in |
| **ESLint** | JavaScript | JS modules | npm | ✅ JS plugins | AST (Espree) | npm packages |
| **Checkov** | Python | Python/YAML | pip / Docker | ✅ Python or YAML | Graph-based | Bundled + external dir |
| **MegaLinter** | Python | YAML descriptors | Docker | ✅ Plugin descriptors | Delegates to linters | Docker images |
| **SonarQube** | Java | Java/XPath | Server + Docker | ⚠️ XPath (limited) / Java plugin | AST (per-language) | Plugin JARs / Marketplace |
| **PMD** | Java | Java/XPath/XML | ZIP (needs JRE) | ✅ XPath rules in XML | AST (JavaCC/Antlr) | XML rulesets |

---

## 3. Patterns That Emerge

### What successful, widely-adopted tools have in common

1. **Declarative rule definitions** — The most adopted tools (Gitleaks, Semgrep, Spectral, Checkov) let users define rules in data formats (TOML, YAML, JSON) rather than requiring code compilation. This dramatically lowers the contribution barrier.

2. **Single binary or zero-config install** — Tools with the fastest adoption (Gitleaks, Trivy, golangci-lint) ship as a single binary with no runtime dependencies. Tools requiring Python/Node.js runtimes (Semgrep, Checkov, ESLint) trade portability for ecosystem access.

3. **Embedded defaults + external override** — Most tools embed a "good default" ruleset but allow full override via external files. Users get value on day one but can customize later.

4. **Separation of "what to scan" from "how to check"** — Clean architectures separate file targeting (globs, paths, extensions) from the check logic itself.

5. **Regex is the universal escape hatch** — Even AST-based tools (Semgrep's spacegrep, PMD's `violationSuppressRegex`) fall back to regex for patterns that don't fit their primary model.

6. **SARIF / JSON output** — All modern tools support structured output formats for CI/CD integration.

7. **Layered complexity** — The most successful tools offer:
   - Simple declarative rules for 80% of cases (TOML/YAML/XPath)
   - Programmatic escape hatch for complex 20% (Python classes, JS functions, Rego)

8. **Rule registries/sharing** — Mature tools develop distribution mechanisms: npm packages (ESLint), YAML file registries (Semgrep), OCI bundles (Trivy), URLs (Spectral).

---

## 4. Recommendation for `cpm` (Code Project Maturity)

### Current State

- C++ core binary + 96 bash shell script checks
- Needs full portability: Linux, macOS, Windows
- Low barrier for rule contribution
- File-level pattern matching (grep-style), not deep AST
- Checks: security anti-patterns, code smells, K8s hardening, doc quality, dependency issues, Dutch content detection

### Recommended Architecture

#### 4.1 Core Language: Go (rewrite from C++)

**Rationale:**

- Single static binary, cross-compiles trivially to Linux/macOS/Windows/ARM
- No runtime dependencies (unlike Python/Java/Node.js)
- Proven model: Gitleaks, Trivy, golangci-lint all demonstrate this works
- Excellent regex engine (`regexp2` for PCRE features if needed)
- Embed files natively with `//go:embed`
- Fast startup, low memory footprint

**Alternative considered:** Rust. Also produces single binaries and has excellent regex. Go is preferred here because it has a larger contributor pool and a more approachable learning curve for rule-engine code (matches the "low barrier" goal).

#### 4.2 Rule Definition Format: YAML (Gitleaks/Semgrep-inspired)

Each check defined as a YAML file:

```yaml
id: SEC-001
title: "Hardcoded secret in Kubernetes manifest"
description: "Secrets should use secretKeyRef, not hardcoded values"
category: security
severity: high
tags: [k8s, secrets, hardening]

# File targeting
target:
  extensions: [".yaml", ".yml"]
  paths_include: ["**/k8s/**", "**/deploy/**"]
  paths_exclude: ["**/test/**"]
  # Optional: require file content match before running patterns
  content_match: "kind:\\s*(Deployment|Pod|StatefulSet)"

# Patterns to detect (any match = finding)
patterns:
  - regex: 'value:\s*["'']?[A-Za-z0-9+/=]{20,}["'']?'
    description: "Base64-encoded secret in plain value field"
  - regex: 'password:\s*\S+'
    not_regex: 'password:\s*\$\{'  # exclude variable references

# Optional: multi-line context matching
context:
  lines_before: 2
  lines_after: 2

# Remediation guidance
fix: "Use `valueFrom.secretKeyRef` instead of hardcoded values"
references:
  - "https://kubernetes.io/docs/concepts/configuration/secret/"
```

**Why YAML over TOML:**

- YAML is more familiar to K8s/DevOps audiences (cpm's primary users)
- Supports multi-line strings naturally (good for regex patterns)
- Widely tooled (schema validation, IDE support)
- Matches the Semgrep/Checkov/Spectral ecosystem conventions

#### 4.3 Rule Evaluation Engine

The engine should be lightweight and match the current grep-style approach:

```text
┌─────────────────────────────────────────────────┐
│                   cpm CLI                        │
├─────────────────────────────────────────────────┤
│  1. File Discovery                              │
│     - Walk project tree                         │
│     - Apply extension/path filters per rule     │
│     - Respect .gitignore / .cpmignore           │
│                                                 │
│  2. Pre-filter (fast path)                      │
│     - content_match: quick regex to decide if   │
│       a file is relevant to a rule at all       │
│     - Skip non-matching files early             │
│                                                 │
│  3. Pattern Matching                            │
│     - Run regex patterns against file content   │
│     - Support: single-line, multi-line, negation│
│     - Capture groups for message interpolation  │
│                                                 │
│  4. Result Aggregation                          │
│     - Deduplicate                               │
│     - Apply severity / category filters         │
│     - Score (maturity model)                    │
│     - Output: terminal, JSON, SARIF, markdown   │
└─────────────────────────────────────────────────┘
```

**Key design choices:**

- **No AST parsing** — stay with regex/grep-style matching. This keeps rules simple and language-agnostic.
- **Pre-filter for performance** — a cheap "does this file even contain K8s manifests?" check before running expensive patterns.
- **Negative patterns** — `not_regex` to reduce false positives (critical for grep-based tools).
- **Multi-line matching** — some patterns span lines (e.g., "a `containers:` block without `securityContext`"). Support `(?s)` dot-matches-newline mode.

#### 4.4 Rule Bundling Strategy

```text
cpm binary (single file)
├── Embedded default rules (via go:embed)
│   └── rules/
│       ├── security/
│       ├── k8s-hardening/
│       ├── code-smells/
│       ├── documentation/
│       ├── dependencies/
│       └── dutch-content/
└── External rule loading
    ├── ~/.cpm/rules/          (user-global)
    ├── .cpm/rules/            (project-local)
    └── --rules-dir <path>     (CLI flag)
```

**Merge strategy:** External rules extend (not replace) embedded rules. Disable specific rules via `.cpm.yaml` config:

```yaml
# .cpm.yaml (project config)
disable:
  - DUTCH-001
  - DUTCH-002

severity_override:
  SEC-003: warning  # downgrade for this project

extra_rules:
  - ./custom-rules/
  - https://example.com/team-rules.tar.gz
```

#### 4.5 Migration Path from Current Architecture

| Phase | Action |
|-------|--------|
| **Phase 1** | Convert 96 bash checks → YAML rule definitions. Most bash checks are `grep -r` patterns — these translate directly. |
| **Phase 2** | Build Go core: file walker, YAML rule loader, regex engine, output formatters. |
| **Phase 3** | Embed converted YAML rules in Go binary. Ship single binary. |
| **Phase 4** | Add rule contribution tooling: `cpm rule new`, `cpm rule test`, schema validation. |
| **Phase 5** | Optional: rule registry (git repo or OCI bundle) for shared organizational rules. |

#### 4.6 Making Rule Contribution Easy

Drawing from ESLint and Semgrep's success:

1. **Rule scaffolding CLI:**

   ```bash
   cpm rule new --id SEC-042 --category security --title "Weak TLS version"
   # Creates rules/security/SEC-042.yaml with template
   ```

2. **Built-in rule testing:**

   ```bash
   cpm rule test rules/security/SEC-042.yaml
   # Runs rule against test fixtures defined inline or in a test/ directory
   ```

   Test cases embedded in the rule YAML (inspired by Semgrep):

   ```yaml
   tests:
     - name: "Should detect TLS 1.0"
       file: "test.yaml"
       content: |
         tls:
           minVersion: "1.0"
       expect: match

     - name: "Should not flag TLS 1.3"
       file: "test.yaml"  
       content: |
         tls:
           minVersion: "1.3"
       expect: no_match
   ```

3. **JSON Schema for rule YAML** — enables IDE autocomplete and validation.

4. **Documentation generation** — `cpm docs generate` creates a markdown table of all rules from their YAML metadata.

#### 4.7 Advanced Patterns (Future)

For checks that can't be expressed as single-regex:

```yaml
id: K8S-015
title: "Container without resource limits"
category: k8s-hardening
severity: high

# Composite pattern: file matches A but NOT B
target:
  extensions: [".yaml", ".yml"]
  content_match: "kind:\\s*Deployment"

composite:
  mode: "match_without"  # A present, B absent
  match:
    regex: 'containers:'
  without:
    regex: 'resources:\s*\n\s+limits:'
    scope: block  # within same YAML block/indentation level
```

This handles "absence" checks (something is missing) which are common in hardening rules.

#### 4.8 Distribution Plan

| Channel | Method |
|---------|--------|
| GitHub Releases | Pre-built binaries for linux/amd64, linux/arm64, darwin/amd64, darwin/arm64, windows/amd64 |
| Homebrew | Tap with formula |
| Docker | `ghcr.io/org/cpm:latest` (for CI usage) |
| Nix | Flake |
| AUR | For Arch Linux users |
| go install | `go install github.com/org/cpm@latest` |

---

## 5. Summary Decision Matrix

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Core language | Go | Single binary, cross-platform, contributor-friendly |
| Rule format | YAML | Familiar to DevOps audience, readable, toolable |
| Rule engine | Regex (Go `regexp`/`regexp2`) | Matches current grep-style approach, no need for AST |
| Rule bundling | `go:embed` + external dirs | Zero-dep default experience + full customizability |
| Distribution | Single binary (multi-platform) | Maximum portability, proven by Gitleaks/Trivy |
| Custom rules | External YAML, no recompile | Critical for adoption and community contributions |
| Config format | YAML (`.cpm.yaml`) | Consistent with rules format, familiar to users |
| Output formats | Terminal (colored), JSON, SARIF, Markdown | CI/CD integration + human readability |

---

## 6. Anti-Patterns to Avoid

1. **Don't require recompilation for custom rules** (golangci-lint's weakness)
2. **Don't require a server** (SonarQube's barrier to adoption)
3. **Don't require Docker for basic usage** (MegaLinter's limitation)
4. **Don't use an unfamiliar DSL** (Rego's learning curve hurts Trivy adoption for custom policies)
5. **Don't hardcode rules in the binary without override** (makes community contribution impossible)
6. **Don't mix rule definition with rule configuration** — keep "what to check" separate from "whether to run it"

---

## 7. References

- Gitleaks: <https://github.com/zricethezav/gitleaks>
- Semgrep: <https://github.com/semgrep/semgrep>
- Spectral: <https://github.com/stoplightio/spectral>
- Trivy: <https://github.com/aquasecurity/trivy>
- golangci-lint: <https://golangci-lint.run/contributing/architecture/>
- ESLint: <https://eslint.org/docs/latest/contribute/architecture/>
- Checkov: <https://github.com/bridgecrewio/checkov>
- MegaLinter: <https://megalinter.io>
- SonarQube: <https://docs.sonarsource.com/sonarqube-server/>
- PMD: <https://pmd.github.io/pmd/>
