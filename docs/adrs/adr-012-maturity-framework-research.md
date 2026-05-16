---
summary: Research on maturity, quality, and health assessment frameworks for cpm adoption
status: proposed
---

# ADR-012: Maturity Framework Research — Comprehensive Assessment Models for cpm

## Context

cpm (Compliance/Prompt Manager) is a CLI tool that enforces quality checks across repositories. To evolve from a basic check runner to a comprehensive maturity assessment framework, we need to understand and potentially adopt established industry frameworks. This ADR researches all known software project maturity, quality, and health assessment frameworks to determine what cpm should measure, check, and enforce.

## Research Summary

### 1. Process Maturity Models

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **CMMI** (Capability Maturity Model Integration) | Organization's process capability across 22 process areas | Partial (self-assessment tools exist) | 5: Initial → Managed → Defined → Quantitatively Managed → Optimizing | High for enterprise adoption; too heavyweight for cpm's scope |
| **SPICE/ISO 15504** | Software process capability assessment | Yes (automated assessment tools) | 6: Incomplete → Performed → Managed → Established → Predictable → Optimizing | Medium; aligns with CMMI, could inform process checks |
| **ITIL** (Information Technology Infrastructure Library) | IT service management maturity | Partial (maturity assessments) | 5: Initial → Reactive → Proactive → Service Level → Optimizing | Low; more relevant for ops than dev tooling |
| **COBIT** (Control Objectives for Information and Related Technologies) | IT governance and management | Partial (frameworks exist) | 6: Non-existent → Initial → Repeatable → Defined → Managed → Optimized | Low; enterprise governance focus |

**cpm Position**: CMMI and SPICE provide good conceptual models for maturity progression. cpm should adopt a simplified 3-4 level model rather than full CMMI complexity.

### 2. Software Quality Models

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **ISO 25010 (SQuaRE)** | 8 quality characteristics: Functional Suitability, Performance Efficiency, Compatibility, Usability, Reliability, Security, Maintainability, Portability | Yes (via metrics) | Not levels-based; characteristic-based | High; maps directly to cpm's quality gates |
| **McCall's Quality Model** | 11 quality factors in 3 categories: Operation (Correctness, Reliability, Efficiency, Integrity, Usability), Revision (Maintainability, Flexibility, Testability), Transition (Portability, Reusability, Interoperability) | Yes | Not levels-based; factor-based | Medium; good for check categorization |
| **Boehm's Model** | 3-tier quality attributes: High-level, Intermediate, Primitive | Partial | Not levels-based | Low; academic focus |
| **FURPS+** | Functionality, Usability, Reliability, Performance, Supportability + Design Constraints, Implementation, Physical, etc. | Yes | Not levels-based | Medium; simple categorization |

**cpm Position**: ISO 25010 is the gold standard. cpm should map its checks to ISO 25010 characteristics for clear taxonomy.

### 3. Cloud-Native Maturity Models

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **12-Factor App** | Cloud-native best practices: Codebase, Dependencies, Config, Backing Services, Build/Release/Run, Processes, Port Binding, Concurrency, Disposability, Dev/Prod Parity, Logs, Admin Processes | Yes | Not levels-based; checklist | High; cpm already has portability checks |
| **15-Factor App** | Extended 12-factor with: API First, Telemetry, Security, Authentication | Yes | Not levels-based | High; natural extension of 12-factor |
| **CNCF Cloud Native Maturity Model** | 6 dimensions: Architecture, Delivery, Security, Platform, Organizational, Cultural | Partial | 5: Ad-hoc → Managed → Defined → Measured → Optimized | Medium; enterprise-focused |

**cpm Position**: 12-factor is essential. cpm should add checks for 15-factor elements (telemetry, security, authentication).

### 4. DevOps Maturity Models

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **DORA Metrics** | 4 key metrics: Deployment Frequency, Lead Time for Changes, Change Failure Rate, Mean Time to Recovery (MTTR) | Yes (via CI/CD analytics) | 4 tiers: Elite, High, Medium, Low | High; cpm can track these via git/CI metadata |
| **Accelerate** (Nicole Forsgren et al.) | 24 capabilities across: Technical, Process, Cultural, Product | Partial | Continuous scale | Medium; research-backed but complex |
| **DevOps Research Assessment** | Organizational DevOps capabilities | No (survey-based) | Not applicable | Low; not automatable |

**cpm Position**: DORA metrics are highly automatable and valuable. cpm should add a `check-dora.sh` that computes these from git/CI data.

### 5. Security Maturity Models

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **OWASP SAMM** (Software Assurance Maturity Model) | 15 security practices across 5 business functions: Governance, Design, Implementation, Verification, Operations | Partial | 4: 0-3 (Foundational → Advanced) | High; cpm already has security scans |
| **BSIMM** (Building Security In Maturity Model) | 12 practices across 4 domains: Governance, Intelligence, SSDL, Deployment | Partial | 4: 1-4 levels per practice | Medium; similar to SAMM |
| **OpenSSF Scorecard** | 18 automated security checks: Branch Protection, Code Review, Dependency Update, etc. | Yes | 0-10 score per check | High; cpm should adopt Scorecard checks |

**cpm Position**: OpenSSF Scorecard is fully automatable and critical. cpm should integrate Scorecard as a core check.

### 6. Architecture Principles

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **SOLID** | 5 principles: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion | Partial (via static analysis) | Not levels-based | Medium; cpm could add lint rules |
| **GRASP** | 9 principles: Controller, Creator, Indirection, Information Expert, Low Coupling, High Cohesion, Polymorphism, Protected Variations, Pure Fabrication | Partial | Not levels-based | Low; design-level, hard to automate |
| **Clean Architecture** | Layered architecture with dependency rule | Partial | Not levels-based | Low; architectural, not checkable |
| **Hexagonal Architecture** | Ports and adapters pattern | Partial | Not levels-based | Low; architectural pattern |

**cpm Position**: SOLID is the most actionable. cpm could add a `check-solid.sh` using static analysis tools.

### 7. Code Quality Tools

| Tool | What It Measures | Automatable | Quality Gate | cpm Adoption Potential |
|------|------------------|-------------|--------------|------------------------|
| **SonarQube** | Bugs, vulnerabilities, code smells, coverage, duplication | Yes | Yes (configurable) | High; cpm could wrap SonarQube |
| **CodeClimate** | Maintainability, test coverage, duplication, complexity | Yes | Yes | Medium; cloud-based |
| **Codacy** | Code patterns, coverage, complexity, duplication | Yes | Yes | Medium; cloud-based |

**cpm Position**: cpm should remain tool-agnostic but provide integration points for these tools.

### 8. Framework-Specific Checks

| Framework | What It Measures | Automatable | cpm Adoption Potential |
|-----------|------------------|-------------|------------------------|
| **Angular CLI lint** | TypeScript, template, style linting | Yes | Low (cpm is language-agnostic) |
| **Nx workspace checks** | Monorepo structure, dependency graph | Yes | Medium; cpm could add monorepo checks |
| **Spring Boot Actuator** | Health, metrics, info endpoints | Yes | Low (JVM-specific) |
| **Rails best practices** | RESTful conventions, ActiveRecord patterns | Partial | Low (Ruby-specific) |
| **ESLint configs** (airbnb, standard) | Code style, best practices | Yes | High; cpm already has syntax checks |

**cpm Position**: cpm should support ESLint/Prettier integration as a universal check.

### 9. Repository Health Standards

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **GitHub Community Standards** | README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, etc. | Yes | Checklist (pass/fail) | High; cpm should add community health checks |
| **GitLab Project Compliance** | Compliance frameworks, security policies | Partial | Framework-based | Medium; GitLab-specific |
| **OpenSSF Scorecard** | 18 security/health checks | Yes | 0-10 score | High (already covered) |

**cpm Position**: GitHub Community Standards is essential. cpm should add `check-community-standards.sh`.

### 10. Testing Maturity Models

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **TDD Maturity Model** | Test-first adoption, coverage, mutation score | Partial | 5: No Tests → Test-Later → Test-First → TDD → Mature TDD | Medium; hard to measure |
| **Test Pyramid** | Unit/Integration/E2E test balance | Yes | Ratio-based | High; cpm can check test ratios |
| **Mutation Testing Score** | Test effectiveness (kills mutants) | Yes | 0-100% | High; cpm could integrate Pitest/Stryker |

**cpm Position**: Test pyramid is actionable. cpm should add `check-test-pyramid.sh`.

### 11. Documentation Maturity

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **Diátaxis Framework** | 4 documentation types: Tutorials, How-to, Reference, Explanation | Partial | Not levels-based | High; cpm should check docs structure |
| **ADR Maturity** | ADR presence, format, status | Yes | Checklist | High; cpm already has dead-docs check |

**cpm Position**: Diátaxis is valuable. cpm should add `check-docs-structure.sh` based on Diátaxis.

### 12. Dependency Health

| Tool | What It Measures | Automatable | Severity Levels | cpm Adoption Potential |
|------|------------------|-------------|-----------------|------------------------|
| **Snyk** | Vulnerabilities, license issues | Yes | Critical/High/Medium/Low | High; cpm already has grype |
| **Dependabot** | Outdated dependencies | Yes | Semantic version based | Medium; cpm could check |
| **Socket.dev** | Supply chain risks | Yes | Risk scores | High; cpm could integrate |
| **npm audit** | Known vulnerabilities | Yes | Critical/High/Moderate/Low | High; cpm already has osv-scan |

**cpm Position**: cpm should add dependency freshness checks (Dependabot-style).

### 13. Accessibility Maturity

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **WCAG 2.1** | Web accessibility compliance | Partial (tools exist) | 3: A, AA, AAA | Low (cpm is CLI, not web) |
| **W3C Accessibility Maturity Model** | Organizational accessibility maturity | Partial | 5: Ad-hoc → Managed → Integrated → Optimized → Innovating | Low; organizational focus |

**cpm Position**: Not applicable for CLI tool. Skip.

### 14. Sustainability

| Framework | What It Measures | Automatable | Maturity Levels | cpm Adoption Potential |
|-----------|------------------|-------------|-----------------|------------------------|
| **Green Software Foundation Patterns** | Energy efficiency, carbon awareness, hardware efficiency | Partial | Not levels-based | Low; emerging field |
| **SOFT Framework** | Strategy, Implementation, Operations, Compliance | Partial | Not levels-based | Low; organizational focus |

**cpm Position**: Could add basic sustainability checks (e.g., energy-efficient code patterns) in future.

## Summary Table: All Frameworks

| Category | Framework | Automatable | Levels | Priority for cpm |
|----------|-----------|-------------|--------|------------------|
| Process | CMMI | Partial | 5 | Low |
| Process | SPICE/ISO 15504 | Yes | 6 | Medium |
| Process | ITIL | Partial | 5 | Low |
| Process | COBIT | Partial | 6 | Low |
| Quality | ISO 25010 | Yes | Characteristic-based | High |
| Quality | McCall | Yes | Factor-based | Medium |
| Quality | FURPS+ | Yes | Factor-based | Medium |
| Cloud | 12-Factor App | Yes | Checklist | High |
| Cloud | 15-Factor App | Yes | Checklist | High |
| Cloud | CNCF Maturity | Partial | 5 | Medium |
| DevOps | DORA Metrics | Yes | 4 tiers | High |
| DevOps | Accelerate | Partial | Continuous | Medium |
| Security | OWASP SAMM | Partial | 4 | High |
| Security | BSIMM | Partial | 4 | Medium |
| Security | OpenSSF Scorecard | Yes | 0-10 | High |
| Architecture | SOLID | Partial | Principles | Medium |
| Architecture | GRASP | Partial | Principles | Low |
| Code Quality | SonarQube | Yes | Configurable | High |
| Code Quality | CodeClimate | Yes | Scores | Medium |
| Code Quality | Codacy | Yes | Scores | Medium |
| Framework | ESLint | Yes | Rules | High |
| Framework | Nx | Yes | Checks | Medium |
| Repository | GitHub Standards | Yes | Checklist | High |
| Repository | OpenSSF Scorecard | Yes | 0-10 | High |
| Testing | Test Pyramid | Yes | Ratio | High |
| Testing | Mutation Score | Yes | 0-100% | Medium |
| Docs | Diátaxis | Partial | Types | High |
| Docs | ADR | Yes | Checklist | High (existing) |
| Dependencies | Snyk | Yes | Severity | High |
| Dependencies | npm audit | Yes | Severity | High (existing) |
| A11y | WCAG | Partial | 3 | Low |
| Sustainability | GSF Patterns | Partial | Patterns | Low |

## What cpm Should Adopt Per Maturity Level

### Level 1: Foundational (Current State)

**Existing cpm checks:**
- `check-licenses.sh` — License compliance
- `check-inclusivity.sh` — Language inclusivity
- `check-unicode.sh` — File encoding
- `check-comment-ratio.sh` — Code documentation
- `check-dead-docs.sh` — Stale documentation
- `check-pii.sh` — PII detection
- `check-version-pins.sh` — Dependency pinning
- `lint-yaml.sh`, `lint-md.sh` — Format linting
- `format-yaml.sh`, `format-md.sh` — Auto-formatting
- `sast-secret.sh` — Secret detection
- `trufflehog-scan.sh` — Advanced secret scanning
- `grype-scan.sh`, `osv-scan.sh` — Vulnerability scanning
- `checkov-scan.sh` — IaC scanning
- `steg-check.sh` — Steganography detection
- `syntax-bash.sh` — Shell syntax
- `check-scripts.sh` — Script validation
- `check-makefile.sh` — Makefile validation
- `check-portability.sh` — Cross-platform compatibility
- `check-file-size.sh` — File size limits
- `check-slop.sh` — Whitespace/formatting
- `check-research-freshness.sh` — Research freshness
- `check-duplication.sh` — Code duplication
- `check-research-freshness.sh` — Knowledge freshness

**Gaps to fill:**
- GitHub Community Standards checklist
- ISO 25010 mapping for all checks
- Basic DORA metrics (deployment frequency, lead time)

### Level 2: Defined (Short-term)

**New checks to add:**
- `check-community-standards.sh` — README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING
- `check-test-pyramid.sh` — Unit/integration/E2E ratio
- `check-dora-metrics.sh` — DORA metrics computation
- `check-openssf-scorecard.sh` — OpenSSF Scorecard integration
- `check-dependency-freshness.sh` — Outdated dependencies
- `check-docs-diataxis.sh` — Documentation structure (tutorials/how-to/reference/explanation)
- `check-solid-principles.sh` — SOLID principle validation (via static analysis)
- `check-12-factor.sh` — 12-factor app compliance
- `check-15-factor.sh` — 15-factor app compliance (telemetry, security, API-first)

**Cross-reference to existing:**
- `check-licenses.sh` → ISO 25010: Security (License compliance)
- `check-inclusivity.sh` → ISO 25010: Usability (Accessibility)
- `check-comment-ratio.sh` → ISO 25010: Maintainability
- `check-pii.sh` → ISO 25010: Security (Privacy)
- `sast-secret.sh`, `trufflehog-scan.sh` → ISO 25010: Security
- `grype-scan.sh`, `osv-scan.sh` → ISO 25010: Reliability (Vulnerability management)
- `checkov-scan.sh` → ISO 25010: Security (Infrastructure security)

### Level 3: Measured (Medium-term)

**New checks to add:**
- `check-mutation-score.sh` — Mutation testing coverage
- `check-complexity-trend.sh` — Cyclomatic complexity over time
- `check-coverage-gate.sh` — Code coverage thresholds
- `check-security-hotspots.sh` — Security hotspot detection
- `check-dependency-health.sh` — Snyk/Socket.dev integration
- `check-codeclimate.sh` — CodeClimate integration
- `check-sonarqube.sh` — SonarQube integration
- `check-codemetrics.sh` — Maintainability index, technical debt

**Metrics to track:**
- DORA metrics trend over time
- Vulnerability age (time to fix)
- Test coverage percentage
- Code duplication percentage
- Complexity growth rate

### Level 4: Optimized (Long-term)

**Advanced checks to add:**
- `check-architecture-compliance.sh` — Architecture boundary enforcement
- `check-supply-chain-security.sh` — SBOM validation, SLSA compliance
- `check-carbon-footprint.sh` — Green software patterns
- `check-accessibility-cli.sh` — CLI accessibility (a11y for terminal)
- `check-performance-benchmark.sh` — Performance regression detection
- `check-ai-safety.sh` — AI/ML model safety checks
- `check-license-compliance.sh` — License compatibility matrix
- `check-regulatory-compliance.sh` — Industry-specific compliance (HIPAA, GDPR, SOC2)

**Maturity indicators:**
- Automated remediation rate
- Mean time to recovery (MTTR)
- Change failure rate
- Deployment success rate

## Cross-Reference: Existing cpm Checks to Frameworks

| cpm Check | ISO 25010 | 12-Factor | DORA | OWASP SAMM | OpenSSF |
|-----------|-----------|-----------|------|------------|---------|
| `check-licenses.sh` | Security | — | — | — | — |
| `check-inclusivity.sh` | Usability | — | — | — | — |
| `check-unicode.sh` | Portability | — | — | — | — |
| `check-comment-ratio.sh` | Maintainability | — | — | — | — |
| `check-dead-docs.sh` | Maintainability | — | — | — | — |
| `check-pii.sh` | Security | — | — | Verification | — |
| `check-version-pins.sh` | — | Dependencies | — | — | Dependency Update |
| `lint-yaml.sh` | Maintainability | — | — | — | — |
| `format-yaml.sh` | Maintainability | — | — | — | — |
| `sast-secret.sh` | Security | — | — | Verification | Secret Scanning |
| `trufflehog-scan.sh` | Security | — | — | Verification | Secret Scanning |
| `grype-scan.sh` | Reliability | — | — | Verification | Vulnerability Scan |
| `osv-scan.sh` | Reliability | — | — | Verification | Vulnerability Scan |
| `checkov-scan.sh` | Security | — | — | Verification | — |
| `steg-check.sh` | Security | — | — | — | — |
| `syntax-bash.sh` | — | — | — | — | — |
| `check-scripts.sh` | — | — | — | — | — |
| `check-makefile.sh` | — | — | — | — | — |
| `check-portability.sh` | Portability | Dev/Prod Parity | — | — | — |
| `check-file-size.sh` | — | — | — | — | — |
| `check-slop.sh` | Maintainability | — | — | — | — |
| `check-research-freshness.sh` | — | — | — | — | — |
| `check-duplication.sh` | Maintainability | — | — | — | Code Review |

## Prioritized List of New Checks to Add

### Priority 1: Critical (Level 2 - Defined)

1. **`check-community-standards.sh`** — GitHub Community Standards checklist
   - Why: Essential for open source health, automatable
   - Checks: README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY.md
   - Existing: None
   - Effort: Low

2. **`check-dora-metrics.sh`** — DORA metrics computation
   - Why: Industry standard for DevOps performance, highly automatable
   - Checks: Deployment frequency, Lead time for changes, Change failure rate, MTTR
   - Existing: None
   - Effort: Medium (requires CI integration)

3. **`check-openssf-scorecard.sh`** — OpenSSF Scorecard integration
   - Why: Critical for security posture, fully automatable
   - Checks: 18 security heuristics (Branch-Protection, Code-Review, etc.)
   - Existing: Partial (sast-secret, trufflehog)
   - Effort: Medium (Scorecard CLI integration)

4. **`check-test-pyramid.sh`** — Test pyramid validation
   - Why: Ensures healthy test distribution
   - Checks: Unit/Integration/E2E ratio, coverage thresholds
   - Existing: None
   - Effort: Low

5. **`check-12-factor.sh`** — 12-factor app compliance
   - Why: Cloud-native best practices, aligns with cpm's portability focus
   - Checks: Codebase, Dependencies, Config, Backing Services, Build/Release/Run, Processes, Port Binding, Concurrency, Disposability, Dev/Prod Parity, Logs, Admin Processes
   - Existing: Partial (check-portability.sh)
   - Effort: Medium

### Priority 2: High (Level 2 - Defined)

6. **`check-dependency-freshness.sh`** — Dependency update detection
   - Why: Prevents dependency drift, complements vulnerability scanning
   - Checks: Outdated dependencies, Dependabot-style alerts
   - Existing: check-version-pins.sh
   - Effort: Low

7. **`check-docs-diataxis.sh`** — Documentation structure validation
   - Why: Improves documentation quality, follows established framework
   - Checks: Tutorials, How-to guides, Reference, Explanation separation
   - Existing: check-dead-docs.sh
   - Effort: Low

8. **`check-15-factor.sh`** — 15-factor app compliance
   - Why: Extends 12-factor for modern cloud-native
   - Checks: API First, Telemetry, Security, Authentication
   - Existing: Partial
   - Effort: Medium

9. **`check-security-hotspots.sh`** — Security hotspot detection
   - Why: Proactive security, complements vulnerability scanning
   - Checks: Dangerous API usage, SQL injection patterns, etc.
   - Existing: sast-secret.sh
   - Effort: Medium

### Priority 3: Medium (Level 3 - Measured)

10. **`check-mutation-score.sh`** — Mutation testing integration
    - Why: Validates test effectiveness, not just coverage
    - Checks: Mutation score percentage, killed vs. survived mutants
    - Existing: None
    - Effort: High (requires tool integration)

11. **`check-complexity-trend.sh`** — Complexity tracking
    - Why: Prevents code rot, enables technical debt management
    - Checks: Cyclomatic complexity growth, maintainability index
    - Existing: None
    - Effort: Medium

12. **`check-dependency-health.sh`** — Dependency health scoring
    - Why: Comprehensive dependency analysis beyond vulnerabilities
    - Checks: Maintenance status, community activity, license compatibility
    - Existing: grype-scan.sh, osv-scan.sh
    - Effort: Medium (Snyk/Socket.dev integration)

13. **`check-coverage-gate.sh`** — Coverage threshold enforcement
    - Why: Ensures minimum test coverage
    - Checks: Line/branch coverage percentages
    - Existing: None
    - Effort: Low

### Priority 4: Future (Level 4 - Optimized)

14. **`check-architecture-compliance.sh`** — Architecture boundary enforcement
15. **`check-supply-chain-security.sh`** — SBOM/SLSA compliance
16. **`check-carbon-footprint.sh`** — Green software patterns
17. **`check-performance-benchmark.sh`** — Performance regression
18. **`check-ai-safety.sh`** — AI/ML safety checks
19. **`check-license-compliance.sh`** — License compatibility matrix
20. **`check-regulatory-compliance.sh`** — Industry compliance (HIPAA, GDPR, SOC2)

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- Add `check-community-standards.sh`
- Add `check-test-pyramid.sh`
- Map existing checks to ISO 25010 characteristics

### Phase 2: DevOps & Security (Weeks 3-4)
- Add `check-dora-metrics.sh`
- Add `check-openssf-scorecard.sh`
- Add `check-12-factor.sh`

### Phase 3: Quality & Dependencies (Weeks 5-6)
- Add `check-dependency-freshness.sh`
- Add `check-docs-diataxis.sh`
- Add `check-security-hotspots.sh`

### Phase 4: Advanced Metrics (Weeks 7-8)
- Add `check-mutation-score.sh`
- Add `check-complexity-trend.sh`
- Add `check-coverage-gate.sh`

## Consequences

- cpm evolves from a check runner to a comprehensive maturity assessment framework
- Clear mapping to industry standards (ISO 25010, DORA, OpenSSF) provides credibility
- Prioritized roadmap ensures incremental value delivery
- Framework-agnostic approach allows adoption of new standards as they emerge
- Existing checks are preserved and enhanced with taxonomy

## References

- CMMI Institute: https://cmmiinstitute.com/
- ISO 25010: https://www.iso.org/standard/78176.html
- 12-Factor App: https://12factor.net/
- DORA Metrics: https://www.dora.dev/
- OWASP SAMM: https://owaspsamm.org/
- OpenSSF Scorecard: https://scorecard.dev/
- Diátaxis Framework: https://diataxis.fr/
- Green Software Foundation: https://greensoftware.foundation/
- SonarQube Quality Gates: https://www.sonarsource.com/
- GitHub Community Standards: https://docs.github.com/en/communities

## Appendix: Framework Comparison Matrix

| Dimension | CMMI | ISO 25010 | DORA | OpenSSF | Diátaxis |
|-----------|------|-----------|------|---------|----------|
| **Focus** | Process capability | Product quality | DevOps performance | Security health | Documentation |
| **Levels** | 5 | N/A (characteristics) | 4 tiers | 0-10 score | N/A (types) |
| **Automatable** | Partial | Yes | Yes | Yes | Partial |
| **cpm Fit** | Low | High | High | High | High |
| **Complexity** | High | Medium | Low | Low | Low |
| **Adoption Cost** | High | Low | Low | Low | Low |