---
summary: cpm sits between git and your code — a learning layer that grows with you.
status: accepted
---

# ADR-013: Product Positioning & Philosophy

## What cpm is

A layer between git and your code that helps you grow as an engineer.

```text
  You → cpm → git → remote
       ↑
       learns with you
       adapts to your level
       never blocks without teaching
```

## Core philosophy

**1. Learning over policing**

cpm is not a gatekeeper. It's a mentor. Every warning explains *why* and links to *how to fix*. You grow in maturity because you understand, not because you're forced.

**2. Intrusive when you want, invisible when you don't**

```toml
# cpm.toml
[enforcement]
level = "learn"    # learn | guide | guard | enforce

# learn:   show tips after commit (non-blocking)
# guide:   show warnings before push (non-blocking)
# guard:   block push on errors, warn on rest
# enforce: block commit on errors + warnings
```

You choose your intensity. Start at `learn`, grow to `enforce` when ready.

**3. Simple bolt-on**

```bash
# Add cpm to any existing repo in 10 seconds:
curl -fsSL https://cpm.dev/install.sh | bash
cd my-project
cpm init
# Done. No config needed. Sensible defaults.
```

No migration. No rewrite. No breaking changes. It bolts on.

**4. Language-agnostic core, language-specific plugins**

```text
lib/cpm/
├── checks/universal/    ← works everywhere (37 checks)
├── checks/cpp/          ← C/C++ projects
├── checks/typescript/   ← TS/JS projects (future)
├── checks/python/       ← Python projects (future)
├── checks/rust/         ← Rust projects (future)
├── checks/terraform/    ← IaC projects (future)
└── checks/java/         ← Java projects (future)
```

Adding a language = adding a directory with checks. No core changes.

**5. Grow with you (maturity progression)**

```text
Level 0: cpm init → formatting + secrets scan
Level 1: + hooks, tests, conventional commits
Level 2: + architecture docs, complexity limits, CI
Level 3: + metrics, trend analysis, mutation testing
Level 4: + auto-remediation, AI-assisted review
```

Each level unlocks naturally. cpm suggests the next step when you're ready:

```text
$ cpm maturity
  Level: 2 (Defined)
  Score: 12/18

  Ready for level 3? Try:
    → cpm enable slop-detection
    → cpm enable timing
```

## Where cpm sits

```text
                    ┌─────────────────────┐
                    │   Your IDE / Editor  │
                    └──────────┬──────────┘
                               │ save
                    ┌──────────▼──────────┐
                    │     Your Code       │
                    └──────────┬──────────┘
                               │ git add
                ┌──────────────▼──────────────┐
                │           cpm               │
                │  ┌─────────────────────┐    │
                │  │ pre-commit: format  │    │
                │  │ pre-push: lint+test │    │
                │  │ post-commit: learn  │    │
                │  └─────────────────────┘    │
                └──────────────┬──────────────┘
                               │ git push
                    ┌──────────▼──────────┐
                    │    CI / Remote      │
                    └─────────────────────┘
```

## What cpm is NOT

- Not a build system (use make, cmake, cargo, npm)
- Not a CI system (use GitHub Actions, GitLab CI)
- Not a linter (it orchestrates linters)
- Not a test runner (it orchestrates test runners)
- Not a package manager (it manages quality tools)

It's the **orchestration and learning layer** between your code and git.

## Competitive positioning

| Tool | Focus | cpm difference |
|------|-------|----------------|
| Husky | Git hooks only | cpm = hooks + checks + learning + metrics |
| lint-staged | Format on commit | cpm = format + lint + security + maturity |
| pre-commit (Python) | Hook manager | cpm = hooks + registry + progression + multi-lang |
| MegaLinter | Run all linters | cpm = linters + teaching + maturity + lightweight |
| SonarQube | Code quality server | cpm = local-first, no server, instant feedback |
| Nx | Monorepo tooling | cpm = any repo, not just monorepos |

## Design constraints

- **Zero runtime deps** — bash + git, nothing else required
- **Offline-first** — works without internet
- **Fast** — pre-commit < 5s, pre-push < 60s
- **Portable** — macOS, Linux, WSL, CI
- **Non-destructive** — never modifies code without consent
- **Inspectable** — `cpm config get`, `cpm maturity`, everything visible

## Framework foundation

cpm's maturity model is NOT CMMI. It combines the best of multiple frameworks:

| Framework | What cpm takes from it | Role in cpm |
|-----------|----------------------|-------------|
| **ISO 25010** | 8 quality characteristics | Taxonomy — *what* we check |
| **DORA** | 4 key metrics | Performance — *how well* you deliver |
| **OpenSSF Scorecard** | 18 security checks | Security posture |
| **12-factor** | Cloud-native checklist | Architecture compliance |
| **Diátaxis** | 4 documentation types | Docs structure |
| **CMMI** | 5-level progression concept | Inspiration for levels (not the content) |

### Why not just CMMI?

CMMI is:

- Organization-focused (not repo-focused)
- Process-heavy (22 process areas, surveys, assessments)
- Not automatable (requires human evaluators)
- Expensive to certify

cpm is:

- Repo-focused (one repo, one score)
- Automated (every check is a script)
- Free (open source, no certification)
- Instant (run `cpm maturity`, get your level)

### cpm's quality taxonomy (from ISO 25010)

Every check maps to a quality characteristic:

| ISO 25010 Characteristic | cpm checks |
|--------------------------|-----------|
| **Maintainability** | comment-ratio, file-size, complexity, dead-code, duplication, slop |
| **Security** | sast-secret, pii, gitleaks, grype, osv, checkov, trufflehog |
| **Reliability** | test-unit, e2e, coverage, mutation |
| **Portability** | portability, unicode, 12-factor |
| **Functional Suitability** | test-unit, e2e, feature-coverage |
| **Performance Efficiency** | timing, complexity, benchmarks |
| **Compatibility** | deps, version-pins, licenses |
| **Usability** | inclusivity, docs-structure, community-standards |

### cpm's performance metrics (from DORA)

| DORA Metric | How cpm measures it |
|-------------|-------------------|
| Deployment Frequency | Commits/merges per week (from git log) |
| Lead Time for Changes | Time from first commit to merge (git timestamps) |
| Change Failure Rate | Reverts / total merges (git log) |
| Mean Time to Recovery | Time between failure commit and fix commit |

### cpm's maturity levels (combined model)

| Level | Name | ISO 25010 focus | DORA tier | OpenSSF score |
|-------|------|----------------|-----------|---------------|
| 0 | Initial | — | — | 0-2 |
| 1 | Managed | Maintainability + Security | Low | 3-4 |
| 2 | Defined | + Reliability + Compatibility | Medium | 5-6 |
| 3 | Measured | + Performance + all metrics | High | 7-8 |
| 4 | Optimized | All characteristics, auto-remediation | Elite | 9-10 |

### Blind spots (what competitors have that cpm doesn't yet)

| Gap | Source framework | Priority | Effort |
|-----|-----------------|----------|--------|
| DORA metrics | DORA/Accelerate | High | Medium (git log parsing) |
| Community standards | GitHub/OpenSSF | High | Low (file existence checks) |
| Test pyramid ratio | Test Pyramid | High | Low (count test types) |
| Dependency freshness | Dependabot/Snyk | High | Medium (version comparison) |
| OpenSSF Scorecard | OpenSSF | Medium | Low (wrap existing tool) |
| Docs structure | Diátaxis | Medium | Low (directory checks) |
| 12-factor compliance | 12-factor | Medium | Medium (config checks) |
| Supply chain (SBOM/SLSA) | NIST/OpenSSF | Low | High (tooling needed) |
| Architecture enforcement | SOLID/Clean | Low | High (static analysis) |

### Architecture patterns (checkable)

| Pattern | What to check | Automatable |
|---------|--------------|-------------|
| **Ports & Adapters (Hexagonal)** | No direct imports between adapters; core has no infra deps | Yes (import graph analysis) |
| **Clean Architecture** | Dependency rule: inner layers don't import outer | Yes (import direction check) |
| **C4 Model** | Context/Container/Component/Code diagrams exist | Partial (file existence) |
| **Hub & Spoke** | Central module, no spoke-to-spoke deps | Yes (dependency graph) |
| **Union/Discriminated types** | Exhaustive pattern matching, no default catch-all | Partial (lint rules) |
| **Pure/Impure split** | Functions with side effects separated from pure logic | Partial (naming convention, IO markers) |

cpm could add `check-architecture.sh` that validates import boundaries based on a declared architecture in `cpm.toml`:

```toml
[architecture]
pattern = "hexagonal"    # hexagonal | clean | layered | hub-spoke
layers = ["domain", "application", "infrastructure", "presentation"]
# domain must not import infrastructure
rules = ["domain !-> infrastructure", "domain !-> presentation"]
```

### Development methodologies (checkable aspects)

| Methodology | What cpm can check | How |
|-------------|-------------------|-----|
| **TDD** | Tests written before/with code (test commit before impl commit) | Git log analysis: test file timestamp vs source |
| **BDD** | Feature files exist, scenarios cover acceptance criteria | File existence: `*.feature`, `*.spec.*` |
| **Pure/Impure separation** | Side-effect functions isolated, marked, or in separate modules | Naming convention (`*_io.rs`, `effects/`) or annotation |
| **DDD** | Bounded contexts, ubiquitous language in code | Directory structure matches domain model |
| **Event Sourcing** | Events are immutable, state derived from events | Pattern detection in code |

### Legal & regulatory compliance (mandatory in many jurisdictions)

| Regulation | What it requires | What cpm can check | Priority |
|------------|-----------------|-------------------|----------|
| **GDPR** (EU) | Data protection, right to erasure, consent | PII detection, data flow annotations, privacy-by-design markers | High |
| **ISO 27001** | Information security management | Secret scanning, access control docs, incident response plan exists | High |
| **ISO 9001** | Quality management system | Process documentation, traceability, audit trail | Medium |
| **SOC 2** | Security, availability, processing integrity | Logging, access controls, change management | Medium |
| **HIPAA** (US healthcare) | Protected health information | PHI detection, encryption verification, audit logs | Low (niche) |
| **PCI DSS** (payments) | Cardholder data protection | PAN detection, encryption, access logging | Low (niche) |
| **NIS2** (EU) | Cybersecurity for essential services | Vulnerability management, incident reporting, supply chain security | Medium |
| **Accessibility (EU/US)** | Equal access for people with disabilities | WCAG checks (web), terminal accessibility (CLI) | Medium |

**What cpm can enforce today:**

- `check-pii.sh` → GDPR (PII detection)
- `sast-secret.sh` → ISO 27001 (no secrets in code)
- `check-licenses.sh` → Legal compliance (license compatibility)
- Audit trail via `.tmp/timings.jsonl` → ISO 9001 (traceability)

**What cpm should add:**

```toml
# cpm.toml
[compliance]
frameworks = ["gdpr", "iso27001"]   # enables relevant checks

# gdpr enables: check-pii, check-data-flow, check-consent-markers
# iso27001 enables: sast-secret, check-access-docs, check-incident-plan
# accessibility enables: check-wcag (web), check-terminal-a11y (CLI)
```

### Accessibility (legally required in EU since 2025)

| Context | Standard | What to check |
|---------|----------|--------------|
| Web apps | WCAG 2.2 AA | axe-core, pa11y, lighthouse a11y score |
| Mobile apps | EN 301 549 | Platform-specific a11y checks |
| CLI tools | No formal standard | NO_COLOR support, screen reader compat, no color-only status |
| Documents | PDF/UA, WCAG | Document structure, alt text, reading order |

cpm already does:

- `NO_COLOR` support in `ui.sh`
- Symbol + label (not color-only) per ADR-123

cpm should add:

- `check-wcag.sh` — wraps axe-core/pa11y for web projects
- `check-terminal-a11y.sh` — verifies NO_COLOR, screen reader hints

### Combined maturity model (final)

| Level | Engineering | Security | Legal | Architecture |
|-------|------------|----------|-------|-------------|
| 0 | Formatting | — | — | — |
| 1 | + tests, hooks | Secrets scan | License check | — |
| 2 | + docs, CI, complexity | + vulnerability scan | + PII detection | Documented (C4) |
| 3 | + DORA metrics, trends | + OpenSSF Scorecard | + GDPR/ISO 27001 checks | Enforced (import rules) |
| 4 | + auto-remediation | + supply chain (SLSA) | + audit trail, SOC 2 | + architecture tests |

### Compliance layering (from enterprise practice)

Not all rules carry the same weight. cpm respects a hierarchy:

| Layer | Mandatory? | cpm enforcement | Example |
|-------|------------|----------------|---------|
| **Law/Regulation** | Yes, no exceptions | `enforce` always | GDPR, NIS2, accessibility |
| **Company Policy** | Yes, waiver possible | `enforce` (unless waiver in cpm.toml) | ISO 27001, access control |
| **Industry Standard** | Usually | `guard` | OWASP Top 10, ISO 25010 |
| **RFC/ADR** | Expected | `guide` | Architecture decisions, tool choices |
| **Non-functionals** | Per project | `guide` | Performance targets, SLA |
| **Values/Principles** | Aspirational | `learn` | SOLID, clean code, inclusivity |

This maps to cpm's enforcement levels:

- `learn` → values, principles (tips)
- `guide` → RFCs, non-functionals (warnings)
- `guard` → industry standards (block push)
- `enforce` → law, policy (block commit)

### Core beliefs (encoded as checks)

These are not just words — each belief maps to an automatable check:

| Belief | Check |
|--------|-------|
| "An inaccessible product is a broken product" | `check-wcag`, `check-terminal-a11y` |
| "An insecure application puts users at risk" | `sast-secret`, `grype-scan`, `osv-scan` |
| "A privacy violation damages trust" | `check-pii`, `check-data-flow` |
| "Good audit trails are accountability" | Timing logs, JUnit reports |
| "If you can't reproduce a change, don't ship it" | Conventional commits, CI green |
| "Hardcoded secrets are never acceptable" | `sast-secret`, `trufflehog-scan` |
| "A deployment must be boring and repeatable" | CI pipeline, `check-12-factor` |
| "Access rights by need, not habit" | `check-codeowners`, branch protection |
| "Inclusivity is not a checkbox, it's a mindset" | `check-inclusivity`, `check-wcag` |
| "Write code like the next maintainer is a violent psychopath with your home address" | `check-complexity`, `check-comment-ratio`, `check-slop` |
| "A repo without maintenance becomes a liability" | `check-dependency-freshness`, `check-dead-code` |

### ISO 25010 as the quality mixing console

ISO 25010 is not a checklist — it's a mixing console. You set the faders per project:

```toml
# cpm.toml — quality profile (like a mixing console)
[quality-profile]
maintainability = "high"      # strict complexity, comment ratio, file size
security = "high"             # all SAST, secrets, PII
reliability = "medium"        # unit tests required, e2e optional
performance = "low"           # no benchmarks required
portability = "medium"        # cross-platform checks
usability = "high"            # accessibility, inclusivity
compatibility = "medium"      # license checks, dep freshness
functional-suitability = "medium"  # test coverage gate
```

Each setting maps to which checks are `enforce` vs `guide` vs `learn`.

## References

- @see docs/adrs/adr-010-resolution-strategy.md
- @see docs/adrs/adr-011-compliance-center.md
- @see docs/adrs/adr-012-maturity-framework-research.md
