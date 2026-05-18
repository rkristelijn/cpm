# ADR-128: Maturity, Process & Quality Matrix

*Status*: Draft · *Date*: 2026-05-18
*Related*: [ADR-126](adr-126-traceability-by-design.md), [ADR-127](adr-127-traceability-scope.md)

## Context

We need a single source of truth that maps:
- **CMMI Maturity Levels** (1-5, with intermediate levels)
- **Process Maturity** (what practices exist at each level)
- **ISO 9126 Quality** (which checks cover which characteristics)
- **cpm Checks** (organized by scope: universal, language, platform, framework)
- **Repository Lifecycle Stage** (prototype → archived)

This matrix reveals **blind spots** — quality characteristics or maturity aspects not covered by existing checks.

## Decision

### Master Matrix: CMMI × Process × ISO 9126 × cpm Checks

```
Legend:
  [L0-L5] = CMMI maturity level (L0 = initial, L5 = optimizing)
  [P0-P5] = Process maturity (P0 = ad-hoc, P5 = optimized)
  [F,S,R,U,E,M,P] = ISO 9126: Functionality, Security, Reliability, Usability, Efficiency, Maintainability, Portability
  ✓ = Implemented   ○ = Partial   ✗ = Gap
```

#### Level 0-1: Initial → Managed (Basic Engineering)

| ISO 9126 | cpm Check | Scope | L0 | L1 | P0 | P1 |
|----------|-----------|-------|----|----|----|----|
| **F** | `code-generic-secrets-scan` | universal | ✓ | ✓ | ○ | ○ |
| **F** | `code-generic-secrets-fast` | universal | ✓ | ✓ | ○ | ○ |
| **F** | `code-generic-vulnerability-scan` | universal | ✗ | ○ | ✗ | ○ |
| **F** | `code-generic-dangerous-patterns` | universal | ✗ | ○ | ✗ | ○ |
| **F** | `code-generic-pii-detection` | universal | ✗ | ○ | ✗ | ○ |
| **S** | `code-generic-owasp-top10` | universal | ✗ | ○ | ✗ | ○ |
| **S** | `code-generic-api-security` | universal | ✗ | ○ | ✗ | ○ |
| **R** | `code-cpp-complexity-measure` | C++ | ✓ | ✓ | ○ | ○ |
| **R** | `code-cpp-comment-measure` | C++ | ✓ | ✓ | ○ | ○ |
| **R** | `code-generic-dead-code` | universal | ✗ | ○ | ✗ | ○ |
| **M** | `code-generic-todo-tracking` | universal | ✓ | ✓ | ○ | ○ |
| **M** | `code-generic-dead-docs` | universal | ✗ | ○ | ✗ | ○ |
| **M** | `code-generic-slop-detection` | universal | ✗ | ○ | ✗ | ○ |
| **P** | `code-generic-portability` | universal | ✗ | ○ | ✗ | ○ |
| **P** | `code-generic-version-pins` | universal | ✗ | ○ | ✗ | ○ |

#### Level 1-2: Managed → Defined (Standardization)

| ISO 9126 | cpm Check | Scope | L1 | L2 | P1 | P2 |
|----------|-----------|-------|----|----|----|----|
| **F** | `code-typescript-audit` | TypeScript | ✗ | ○ | ✗ | ○ |
| **F** | `code-javascript-audit` | JavaScript | ✗ | ○ | ✗ | ○ |
| **F** | `code-php-audit` | PHP | ✗ | ○ | ✗ | ○ |
| **F** | `code-python-audit` | Python | ✗ | ○ | ✗ | ○ |
| **F** | `code-rust-audit` | Rust | ✗ | ○ | ✗ | ○ |
| **F** | `code-java-audit` | Java | ✗ | ○ | ✗ | ○ |
| **F** | `code-generic-lockfile` | universal | ✓ | ✓ | ○ | ○ |
| **F** | `code-generic-dependency-placement` | universal | ✗ | ○ | ✗ | ○ |
| **S** | `code-generic-crypto-usage` | universal | ✗ | ○ | ✗ | ○ |
| **S** | `code-generic-shadow-variables` | universal | ✗ | ○ | ✗ | ○ |
| **S** | `code-generic-env-config` | universal | ✗ | ○ | ✗ | ○ |
| **R** | `code-generic-async-style` | universal | ✗ | ○ | ✗ | ○ |
| **R** | `code-generic-error-handling` | universal | ✗ | ○ | ✗ | ○ |
| **U** | `code-generic-accessibility` | universal | ✗ | ○ | ✗ | ○ |
| **U** | `code-generic-inclusivity` | universal | ✗ | ○ | ✗ | ○ |
| **U** | `code-generic-unicode` | universal | ✗ | ○ | ✗ | ○ |
| **M** | `code-generic-code-smells` | universal | ✗ | ○ | ✗ | ○ |
| **M** | `code-generic-antipatterns` | universal | ✗ | ○ | ✗ | ○ |
| **M** | `code-generic-circular-deps` | universal | ✗ | ○ | ✗ | ○ |
| **M** | `code-generic-filesize` | universal | ✗ | ○ | ✗ | ○ |
| **P** | `code-generic-runtime-eol` | universal | ✗ | ○ | ✗ | ○ |

#### Level 2-3: Defined → Quantitatively Managed (Measurement)

| ISO 9126 | cpm Check | Scope | L2 | L3 | P2 | P3 |
|----------|-----------|-------|----|----|----|----|
| **F** | `code-typescript-typecheck` | TypeScript | ✗ | ○ | ✗ | ○ |
| **F** | `code-typescript-complexity` | TypeScript | ✗ | ○ | ✗ | ○ |
| **F** | `code-javascript-lint` | JavaScript | ✗ | ○ | ✗ | ○ |
| **F** | `code-php-lint` | PHP | ✗ | ○ | ✗ | ○ |
| **F** | `code-python-lint` | Python | ✗ | ○ | ✗ | ○ |
| **F** | `code-generic-imports` | universal | ✗ | ○ | ✗ | ○ |
| **F** | `code-generic-deprecated` | universal | ✗ | ○ | ✗ | ○ |
| **F** | `code-generic-outdated` | universal | ✗ | ○ | ✗ | ○ |
| **R** | `code-cpp-mutation-testing` | C++ | ✗ | ✗ | ✗ | ✗ |
| **R** | `code-generic-test-coverage` | universal | ✗ | ○ | ✗ | ○ |
| **U** | `code-web-accessibility` | browser | ✗ | ○ | ✗ | ○ |
| **U** | `code-web-inclusivity` | browser | ✗ | ○ | ✗ | ○ |
| **E** | `code-generic-performance` | universal | ✗ | ○ | ✗ | ○ |
| **E** | `code-web-bundle-size` | browser | ✗ | ○ | ✗ | ○ |
| **M** | `code-generic-documentation` | universal | ✗ | ○ | ✗ | ○ |
| **M** | `code-cpp-doxygen` | C++ | ✓ | ✓ | ○ | ○ |
| **M** | `code-generic-architecture` | universal | ✗ | ○ | ✗ | ○ |

#### Level 3-4: Quantitatively Managed → Optimizing (Optimization)

| ISO 9126 | cpm Check | Scope | L3 | L4 | P3 | P4 |
|----------|-----------|-------|----|----|----|----|
| **F** | `code-generic-security-audit` | universal | ✗ | ✗ | ✗ | ✗ |
| **F** | `code-generic-sast` | universal | ✗ | ○ | ✗ | ○ |
| **F** | `code-generic-license-audit` | universal | ✗ | ○ | ✗ | ○ |
| **F** | `code-generic-sbom` | universal | ✗ | ✗ | ✗ | ✗ |
| **F** | `code-web-seo` | browser | ✗ | ✗ | ✗ | ✗ |
| **F** | `code-web-logging` | browser | ✗ | ✗ | ✗ | ✗ |
| **R** | `code-generic-fault-injection` | universal | ✗ | ✗ | ✗ | ✗ |
| **R** | `code-generic-chaos-testing` | universal | ✗ | ✗ | ✗ | ✗ |
| **E** | `code-generic-benchmarking` | universal | ✗ | ✗ | ✗ | ✗ |
| **E** | `code-generic-profiling` | universal | ✗ | ✗ | ✗ | ✗ |
| **M** | `code-generic-refactoring` | universal | ✗ | ✗ | ✗ | ✗ |
| **M** | `code-generic-tech-debt-ratio` | universal | ✗ | ✗ | ✗ | ✗ |
| **M** | `code-generic-complexity-trend` | universal | ✗ | ✗ | ✗ | ✗ |

#### Level 4-5: Optimizing → Continuous Improvement

| ISO 9126 | cpm Check | Scope | L4 | L5 | P4 | P5 |
|----------|-----------|-------|----|----|----|----|
| **F** | `code-generic-auto-fix` | universal | ✗ | ✗ | ✗ | ✗ |
| **F** | `code-generic-auto-refactor` | universal | ✗ | ✗ | ✗ | ✗ |
| **F** | `code-generic-ai-suggestions` | universal | ✗ | ✗ | ✗ | ✗ |
| **R** | `code-generic-flaky-test-detection` | universal | ✗ | ✗ | ✗ | ✗ |
| **R** | `code-generic-self-healing` | universal | ✗ | ✗ | ✗ | ✗ |
| **M** | `code-generic-auto-documentation` | universal | ✗ | ✗ | ✗ | ✗ |
| **M** | `code-generic-pattern-evolution` | universal | ✗ | ✗ | ✗ | ✗ |

### Platform-Specific Checks

| Platform | ISO 9126 | cpm Check | Status |
|----------|----------|-----------|--------|
| **Node.js** | F | `code-node-audit` | ✗ Gap |
| **Node.js** | F | `code-node-package-json` | ✗ Gap |
| **Node.js** | F | `code-node-engines` | ✗ Gap |
| **Node.js** | P | `code-node-runtime-eol` | ✗ Gap |
| **Browser** | F | `code-web-framework-misuse` | ✓ |
| **Browser** | F | `code-web-logging` | ✗ Gap |
| **Browser** | U | `code-web-a11y` | ✗ Gap |
| **Browser** | E | `code-web-bundle-size` | ✗ Gap |
| **Browser** | E | `code-web-seo` | ✗ Gap |
| **Docker** | P | `code-docker-best-practices` | ✗ Gap |
| **Kubernetes** | P | `code-k8s-manifests` | ✗ Gap |
| **Terraform** | F | `code-terraform-validate` | ✗ Gap |
| **Terraform** | S | `code-terraform-security` | ✗ Gap |

### Framework-Specific Checks

| Framework | ISO 9126 | cpm Check | Status |
|-----------|----------|-----------|--------|
| **React** | F | `code-react-hooks` | ✗ Gap |
| **React** | F | `code-react-deps` | ✗ Gap |
| **React** | M | `code-react-best-practices` | ✗ Gap |
| **Angular** | F | `code-angular-modules` | ✗ Gap |
| **Angular** | M | `code-angular-lint` | ✗ Gap |
| **Next.js** | F | `code-nextjs-routes` | ✗ Gap |
| **Next.js** | E | `code-nextjs-ssg-ssr` | ✗ Gap |
| **NestJS** | F | `code-nestjs-modules` | ✗ Gap |
| **NestJS** | M | `code-nestjs-decorators` | ✗ Gap |
| **Vue** | F | `code-vue-composition` | ✗ Gap |
| **Express** | F | `code-express-middleware` | ✗ Gap |
| **Django** | F | `code-django-models` | ✗ Gap |
| **Spring** | F | `code-spring-autowire` | ✗ Gap |

### Repository Lifecycle Stages

The **stage** of a repository determines which checks are active and how strict they are applied.

| Stage | Description | Dev Mode | Strictness | Checks Active |
|-------|-------------|----------|------------|---------------|
| **Prototype** | Exploration, PoC, learning | Active | Low | Syntax only, no security |
| **MVP** | Core features working, validating | Active | Medium | Security + basic quality |
| **Production** | Active users, active development | Active | High | All checks enabled |
| **Maintenance** | Bug fixes only, no new features | Active | Medium | Security + regressions |
| **Legacy** | Deprecated, minimal changes | Read-only | Low | Security only |
| **Archived** | No maintenance, historical | Read-only | Minimal | None (read-only) |

### Strictness Matrix by Stage

```
Stage        │ Syntax │ Security │ Quality │ Coverage │ Docs │ Complexity
─────────────┼────────┼──────────┼─────────┼──────────┼──────┼───────────
Prototype    │   ✓    │    ○     │    ✗    │    ✗     │   ✗  │     ✗
MVP          │   ✓    │    ✓     │    ○    │    ✗     │   ○  │     ○
Production   │   ✓    │    ✓     │    ✓    │    ○     │   ✓  │     ✓
Maintenance  │   ✓    │    ✓     │    ○    │    ✗     │   ○  │     ○
Legacy       │   ○    │    ✓     │    ✗    │    ✗     │   ✗  │     ✗
Archived     │   ✗    │    ○     │    ✗    │    ✗     │   ✗  │     ✗

✓ = Full    ○ = Reduced    ✗ = None
```

### Stage × CMMI Matrix

| Stage | L0 | L1 | L2 | L3 | L4 | L5 |
|-------|----|----|----|----|----|---|
| **Prototype** | ✓ | ○ | ✗ | ✗ | ✗ | ✗ |
| **MVP** | ○ | ✓ | ○ | ✗ | ✗ | ✗ |
| **Production** | ✗ | ○ | ✓ | ○ | ○ | ✗ |
| **Maintenance** | ✗ | ✗ | ○ | ✓ | ○ | ✗ |
| **Legacy** | ✗ | ✗ | ✗ | ○ | ✓ | ○ |
| **Archived** | ✗ | ✗ | ✗ | ✗ | ○ | ✓ |

### cpm.toml Configuration

```toml
[project]
# Repository lifecycle stage
stage = "production"   # prototype | mvp | production | maintenance | legacy | archived

[checks]
# Strictness is automatically adjusted based on stage:
# - prototype: only syntax checks
# - mvp: syntax + security + basic quality
# - production: all checks
# - maintenance: security + regressions
# - legacy: security only
# - archived: none
```

### Blind Spots Analysis

#### Critical Gaps (High Priority)

| Gap | ISO 9126 | Impact | Suggested Check |
|-----|----------|--------|-----------------|
| No test coverage tracking | R | Can't measure reliability | `code-generic-test-coverage` |
| No mutation testing | R | Tests may not be effective | `code-cpp-mutation-testing` |
| No SAST integration | F/S | Security blind spot | `code-generic-sast` |
| No SBOM generation | F | Supply chain risk | `code-generic-sbom` |
| No Node.js audit | F | Dependency vulnerabilities | `code-node-audit` |

#### Medium Gaps

| Gap | ISO 9126 | Impact | Suggested Check |
|-----|----------|--------|-----------------|
| No framework checks | F/M | Framework misuse | `code-react-hooks`, etc. |
| No platform checks | P | Portability issues | `code-docker-best-practices` |
| No performance benchmarks | E | Efficiency unknown | `code-generic-benchmarking` |
| No accessibility checks | U | Usability issues | `code-web-a11y` |

#### Low Gaps (Future)

| Gap | ISO 9126 | Impact | Suggested Check |
|-----|----------|--------|-----------------|
| No AI suggestions | M | Optimization potential | `code-generic-ai-suggestions` |
| No self-healing | R | Recovery potential | `code-generic-self-healing` |
| No pattern evolution | M | Technical debt growth | `code-generic-pattern-evolution` |

### Process Maturity Mapping

| CMMI Level | Process | Quality Gate | Automation |
|------------|---------|--------------|------------|
| **L0: Initial** | Ad-hoc, reactive | None | Manual |
| **L1: Managed** | Basic checks exist | Pre-commit hooks | `cpm check --fast` |
| **L2: Defined** | Standardized process | Pre-push validation | `cpm check` |
| **L3: Quantitatively Managed** | Metrics collected | CI/CD integration | `cpm check --full` |
| **L4: Optimizing** | Continuous improvement | Automated remediation | `cpm auto-fix` |
| **L5: Continuous Improvement** | Self-optimizing | AI-assisted development | `cpm ai-suggest` |

## Consequences

### Positive
- Single source of truth for maturity/quality mapping
- Clear visibility into blind spots
- Prioritized roadmap for check development
- Traceability from CMMI to ISO 9126 to cpm checks
- Stage-based strictness prevents over-engineering

### Negative
- Complex matrix requires maintenance
- Some checks may never be implemented (low value)
- Risk of over-engineering
- Stage transitions need manual intervention

## References

- [ISO/IEC 9126](https://en.wikipedia.org/wiki/ISO/IEC_9126)
- [CMMI Maturity Levels](https://en.wikipedia.org/wiki/Capability_Maturity_Model_Integration)
- [ADR-126: Traceability by Design](adr-126-traceability-by-design.md)
- [ADR-127: Traceability Scope](adr-127-traceability-scope.md)