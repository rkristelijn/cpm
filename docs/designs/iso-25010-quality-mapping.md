# Design: ISO 25010 Quality Model Integration

**Status**: Draft
**Date**: 2026-08-27
**Related**: ADR-012, ADR-013, ADR-127, ADR-128, ADR-140

## Context

cpm currently has 792 rules across ~50 categories. These evolved organically — security checks came first, quality checks followed, then accessibility, supply chain, and framework-specific rules. The result is thorough but inconsistent: some quality characteristics have deep coverage while others have barely any.

ISO/IEC 25010:2023 provides a standardized taxonomy of 9 quality characteristics that can:

1. Help users understand what cpm checks (and doesn't)
2. Guide rule development priorities
3. Enable compliance reporting (ISO 25010 is referenced by ISO 27001, SOC 2, CMMI)
4. Power the maturity scoring model (ADR-128)

ADR-140 already maps checks to compliance frameworks (ISO 27001, OWASP, SOC 2). This design extends that work by mapping every `.rule` file to ISO 25010 characteristics, giving cpm a unified quality taxonomy.

## Current State

Estimated coverage heatmap based on the 797 `.rule` files and existing checks:

```text
Security          ████████████████████░░░ 85%  (280 rules)
Maintainability   █████████████████░░░░░░ 65%  (90 rules)
Reliability       ██████████████░░░░░░░░░ 55%  (35 rules)
Compatibility     █████████████░░░░░░░░░░ 50%  (45 rules)
Flexibility       █████████████░░░░░░░░░░ 50%  (55 rules)
Interaction Cap.  ████████████░░░░░░░░░░░ 45%  (150 rules)
Perf. Efficiency  ██████████░░░░░░░░░░░░░ 40%  (30 rules)
Safety            ██████████░░░░░░░░░░░░░ 40%  (80 rules)
Func. Suitability ████████░░░░░░░░░░░░░░░ 30%  (25 rules)
```

Key observations:

- **Security dominates** — secrets, SAST, OWASP, PII, supply chain rules make up ~35% of all rules
- **Interaction Capability is high in count** — 150 rules from WCAG/accessibility, but coverage of the full sub-characteristic set (accessibility, user engagement, user assistance, self-descriptiveness) is uneven
- **Functional Suitability is weakest** — cpm checks for test existence but not test quality, feature coverage, or correctness
- **Safety is new in ISO 25010:2023** — maps to data loss prevention, operational safety, and hazard mitigation; cpm has some coverage through dangerous-pattern rules but no dedicated safety category

### ISO 25010:2023 characteristics and sub-characteristics

For reference, the complete taxonomy:

| Characteristic | Sub-characteristics |
|---|---|
| Functional Suitability | Functional completeness, correctness, appropriateness |
| Performance Efficiency | Time behaviour, resource utilization, capacity |
| Compatibility | Co-existence, interoperability |
| Interaction Capability | Accessibility, user engagement, user assistance, self-descriptiveness |
| Reliability | Availability, fault tolerance, recoverability, maturity |
| Security | Confidentiality, integrity, non-repudiation, accountability, authenticity, resistance |
| Maintainability | Modularity, reusability, analysability, modifiability, testability |
| Flexibility | Adaptability, scalability, installability, replaceability |
| Safety | Operational constraint, risk identification, fail safe, hazard warning, safe integration |

## Proposal

### 1. Tag every rule with its ISO 25010 characteristic

Extend the `.rule` format with an optional `quality` field. Values follow the pattern `<characteristic>.<sub-characteristic>`:

```text
id: SEC-010
title: Hardcoded AWS Access Key
category: security
quality: security.confidentiality
severity: error
engine: pattern
target:
  extensions: .py .js .ts .java .go .rb .php .rs
  exclude_paths: test/ tests/ vendor/ .git/
patterns:
  - regex: AKIA[0-9A-Z]{16}
    message: "AWS access key hardcoded — rotate immediately"
fix: "Use environment variables or AWS SSO. Run: aws sts get-caller-identity to check exposure."
```

Valid characteristic prefixes (matching ISO 25010:2023):

| Prefix | Characteristic | Example sub-characteristics |
|---|---|---|
| `functional-suitability` | Functional Suitability | `.completeness`, `.correctness`, `.appropriateness` |
| `performance-efficiency` | Performance Efficiency | `.time-behaviour`, `.resource-utilization`, `.capacity` |
| `compatibility` | Compatibility | `.co-existence`, `.interoperability` |
| `interaction-capability` | Interaction Capability | `.accessibility`, `.user-engagement`, `.user-assistance`, `.self-descriptiveness` |
| `reliability` | Reliability | `.availability`, `.fault-tolerance`, `.recoverability`, `.maturity` |
| `security` | Security | `.confidentiality`, `.integrity`, `.non-repudiation`, `.accountability`, `.authenticity`, `.resistance` |
| `maintainability` | Maintainability | `.modularity`, `.reusability`, `.analysability`, `.modifiability`, `.testability` |
| `flexibility` | Flexibility | `.adaptability`, `.scalability`, `.installability`, `.replaceability` |
| `safety` | Safety | `.operational-constraint`, `.risk-identification`, `.fail-safe`, `.hazard-warning`, `.safe-integration` |

Rules may specify characteristic only (e.g., `quality: security`) or characteristic + sub-characteristic (e.g., `quality: security.confidentiality`). The sub-characteristic enables fine-grained reporting but is not required.

#### Mapping existing categories

| Existing category | Primary ISO 25010 mapping | Rationale |
|---|---|---|
| `security` | `security.confidentiality` | Secrets, SAST, OWASP |
| `pii` | `security.confidentiality` | Data protection (also GDPR per ADR-140) |
| `supply-chain` | `security.integrity` | Lockfile, dependency confusion, postinstall |
| `vulnerability` | `security.resistance` | CVE detection, known vulns |
| `quality` | `maintainability.analysability` | Complexity, comments, file size |
| `antipattern` | `maintainability.modifiability` | Code smells, dead code |
| `testing` | `maintainability.testability` | Test existence, coverage |
| `architecture` | `maintainability.modularity` | Circular deps, fan-out, coupling |
| `accessibility` | `interaction-capability.accessibility` | WCAG rules |
| `inclusivity` | `interaction-capability.accessibility` | Inclusive language (alex) |
| `docs` | `interaction-capability.self-descriptiveness` | Prose lint, spelling, broken links |
| `devops` | `reliability.availability` | CI pipeline, build system |
| `portability` | `flexibility.adaptability` | Cross-platform, Unicode |
| `license` | `compatibility.co-existence` | License compatibility |
| `deps` | `compatibility.interoperability` | Version pins, outdated deps |
| `performance` | `performance-efficiency.time-behaviour` | Timeout, async patterns |
| `bundler` | `flexibility.scalability` | Bundle size, tree-shaking |
| `framework` | varies | Maps per rule (Spring Boot → security, React → safety) |

#### Impact on `Rule` struct

Add one field to the existing struct in `rule_engine.h`:

```cpp
struct Rule {
  std::string id;
  std::string title;
  std::string category;
  std::string quality;     // NEW: ISO 25010 mapping, e.g. "security.confidentiality"
  std::string severity;
  std::string engine;
  std::string fix;
  bool skip_comments = false;
  bool skip_strings = false;
  RuleTarget target;
  std::vector<RulePattern> patterns;
};
```

Parsed in `rule_parse()` alongside existing fields. Empty string if not specified (backward compatible).

This enables:

- `cpm findings --quality maintainability` — filter by quality characteristic
- `cpm score --breakdown` — show score per ISO 25010 characteristic
- Compliance reports mapping findings to ISO 25010 (extends ADR-140)

### 2. Quality dashboard in `cpm score`

Extend the score output to show a per-characteristic breakdown:

```text
$ cpm score --breakdown

  cpm score: 72/100 (Level 3: measured)
  ─────────────────────────────────────
  Security          ████████░░  82%   280 rules, 3 findings
  Maintainability   ███████░░░  68%    90 rules, 12 findings
  Reliability       ██████░░░░  55%    35 rules, 5 findings
  Compatibility     █████░░░░░  50%    45 rules, 0 findings
  Flexibility       █████░░░░░  50%    55 rules, 2 findings
  Interaction Cap.  ████░░░░░░  45%   150 rules, 8 findings
  Perf. Efficiency  ████░░░░░░  40%    30 rules, 1 finding
  Safety            ████░░░░░░  40%    80 rules, 0 findings
  Func. Suitability ███░░░░░░░  30%    25 rules, 4 findings
```

Score per characteristic = `(applicable_rules - findings) / applicable_rules × 100`. This follows the same model as the overall cpm score (pass rate), keeping it understandable.

The `--breakdown` flag adds the per-characteristic view without changing the default `cpm score` output (no breaking change).

### 3. Gap-driven rule development

Use the coverage gaps to prioritize new rules. Each gap is a sub-characteristic with few or no rules:

| Priority | Characteristic | Gap | Proposed rules | Effort |
|---|---|---|---|---|
| 1 | Performance Efficiency | N+1 query detection | ORM `.find()` in loops, sequential awaits, unbounded queries | Medium |
| 2 | Reliability | Circuit breaker patterns | Retry without backoff, no timeout on external calls, missing fallback | Low |
| 3 | Reliability | Chaos readiness | No fallback for external dependencies, no graceful degradation | Medium |
| 4 | Maintainability | Dead code detection | Unused exports, unreachable branches, orphan files | High |
| 5 | Maintainability | Coupling metrics | Import fan-out > threshold, god modules, bidirectional deps | Medium |
| 6 | Security | Audit logging | Endpoints without audit trail, missing access logging | Low |
| 7 | Compatibility | API contract drift | OpenAPI spec vs implementation mismatch, schema version conflict | High |
| 8 | Functional Suitability | Feature flag hygiene | Stale flags, nested flags, flag in data layer | Low |
| 9 | Flexibility | Bundle size limits | Output exceeds threshold, unshaken imports | Medium |
| 10 | Safety | Data loss prevention | DELETE without soft-delete, DROP without backup check, cascade delete | Low |

These close the biggest gaps first (Functional Suitability at 30%, Performance Efficiency at 40%) while adding depth to already-covered areas.

### 4. Maturity model integration

Map maturity levels to ISO 25010 coverage thresholds. This extends the maturity model from ADR-128 with concrete quality requirements:

| Level | Name | ISO 25010 requirement |
|---|---|---|
| 0 | Initial | No quality checks |
| 1 | Managed | Security ≥ 1 check |
| 2 | Defined | Security + Maintainability + Reliability each ≥ 1 check |
| 3 | Measured | All 9 characteristics have ≥ 1 check |
| 4 | Optimized | All 9 characteristics score ≥ 50% |
| 5 | Excellent | All 9 characteristics score ≥ 75% |

This gives projects a clear growth path:

```text
$ cpm score

  cpm score: 58/100 (Level 2: defined)
  ─────────────────────────────────────
  ⚠ Level 3 requires all 9 ISO 25010 characteristics covered.
    Missing: Performance Efficiency, Functional Suitability

  Try:
    → Add a timeout check (performance-efficiency.time-behaviour)
    → Add test coverage gate (functional-suitability.completeness)
```

The enforcement level (learn/guide/guard/enforce from ADR-013) controls whether missing characteristics are tips, warnings, or blockers:

| Enforcement | Missing characteristic behavior |
|---|---|
| `learn` | Shown as tip after commit |
| `guide` | Shown as warning before push |
| `guard` | Blocks push if target level not met |
| `enforce` | Blocks commit if target level not met |

### 5. Quality profile (mixing console)

As described in ADR-013, ISO 25010 acts as a mixing console — projects set emphasis per characteristic:

```toml
# cpm.toml
[quality-profile]
security = "high"              # all security rules enforced
maintainability = "high"       # strict complexity, comments, coupling
reliability = "medium"         # unit tests required, e2e optional
performance-efficiency = "low" # no benchmarks required yet
compatibility = "medium"       # license + dep checks
interaction-capability = "high" # full WCAG + inclusivity
flexibility = "medium"         # portability checks
functional-suitability = "low" # growing into this
safety = "low"                 # not safety-critical software
```

Each level maps to rule activation:

| Profile level | Behavior |
|---|---|
| `off` | Rules in this characteristic are skipped |
| `low` | Only error-severity rules active |
| `medium` | Error + warning rules active |
| `high` | All rules active (error + warning + info) |

Default: all characteristics at `medium` (zero config needed).

## Implementation plan

### Phase 1: Tagging (no code changes to rule engine)

- Add `quality:` field to all 797 `.rule` files
- Create mapping reference: `docs/compliance/iso-25010.md`
- Validate: every `.rule` file has a valid `quality:` value (add a check for this)
- Estimated: ~4 hours of mechanical work (bulk script + manual review)

### Phase 2: Parsing (minimal rule_engine changes)

- Add `std::string quality` to `Rule` struct in `rule_engine.h`
- Parse `quality:` line in `rule_parse()` in `rule_engine.cpp`
- Add `--quality <characteristic>` filter to `cmd_rule_scan.cpp`
- Pass `quality` through to `RuleFinding` for reporting
- Tests: extend `rules_test.cpp` to cover `quality:` field parsing
- Estimated: 1-2 hours

### Phase 3: Reporting (score integration)

- Add quality breakdown to `cpm score` output
- Compute per-characteristic pass rate from findings
- Add `--breakdown` flag to score command
- Add characteristic-level summary to JUnit XML output
- Estimated: 3-4 hours

### Phase 4: Gap closure (new rules)

- Implement priority 1-5 gap rules (~30-50 new `.rule` files)
- Target: all 9 characteristics at ≥ 50% coverage
- Focus on pattern-engine rules (no new tool dependencies)
- Estimated: 2-3 days

### Phase 5: Maturity integration

- Update maturity scoring to incorporate ISO 25010 thresholds
- Add growth suggestions per characteristic
- Integrate quality profile (`[quality-profile]`) in config resolution
- Estimated: 1-2 days

## Alternatives considered

### Map to ISO 9126 instead

Rejected — ISO 9126 is superseded by ISO 25010:2023. The newer standard adds Safety (critical for modern software where data loss = harm), Interaction Capability (replaces Usability with a broader scope including accessibility), and Flexibility (replaces Portability with scalability and adaptability). ADR-128 already references ISO 9126 — this design migrates to the current standard.

### Create our own quality taxonomy

Rejected — ISO 25010 is industry-standard, well-understood, and mapped by other tools (SonarQube, CodeClimate, etc.). Using a recognized standard makes cpm's quality model credible, comparable, and useful for compliance reporting. ADR-013 already identifies ISO 25010 as cpm's quality taxonomy.

### Map at category level only (not per-rule)

Rejected — too coarse. A single category like `quality` spans multiple characteristics (Maintainability, Reliability, Functional Suitability). The `antipattern` category includes rules that map to Maintainability (dead code), Reliability (error swallowing), and Safety (unchecked delete). Per-rule tagging gives accurate reporting and meaningful gap analysis.

### Add multiple quality tags per rule

Considered but deferred. Some rules genuinely span characteristics (e.g., a timeout rule touches both Reliability and Performance Efficiency). For simplicity, each rule gets one primary characteristic. If needed later, the field could accept a comma-separated list without breaking the format.

## References

- [ISO/IEC 25010:2023](https://www.iso.org/standard/78176.html) — Systems and software quality models
- [ADR-012](../adrs/adr-012-maturity-framework-research.md) — Maturity framework research
- [ADR-013](../adrs/adr-013-product-positioning.md) — Product positioning (ISO 25010 as mixing console)
- [ADR-127](../adrs/adr-127-traceability-scope.md) — Traceability scope
- [ADR-128](../adrs/adr-128-maturity-quality-matrix.md) — Maturity, process & quality matrix
- [ADR-140](../adrs/adr-140-compliance-framework-mapping.md) — Compliance framework mapping
