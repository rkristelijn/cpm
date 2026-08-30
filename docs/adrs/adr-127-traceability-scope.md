# ADR-127: Traceability Scope & Quality Model

> 🟠 **Status: Partially Implemented** — Basic @see references exist but full bidirectional traceability was not implemented.

*Status*: Partially Implemented · *Date*: 2026-05-18
*Related*: [ADR-126](adr-126-traceability-by-design.md)

## Context

ADR-126 defines traceability mechanisms, but doesn't define **what to trace**. Some artifacts change too frequently to be useful in a traceability matrix.

**Question**: What artifacts should be traced, and which should be excluded?

## Decision

### Traceability Scope: Stable Artifacts Only

| Artifact | Stability | Traces To | Why |
|----------|-----------|-----------|-----|
| **ADRs** | High | Designs, code | Decisions rarely change |
| **Designs** (drawio) | High | ADRs, code | Architecture is stable |
| **Code** | Medium | ADRs, designs | Implementation follows design |
| **Unit tests** | High | Code, requirements | Tests match code |
| **E2E tests** | Medium | Acceptance criteria | Tests match requirements |

### Excluded Artifacts (Too Dynamic)

| Artifact | Reason for Exclusion |
|----------|---------------------|
| **Tickets** | Move too much, short-lived |
| **Projects** | Too dynamic, reorganize often |
| **Roadmaps** | Change with strategy |
| **Sprints** | Temporary, burn down only |

### ISO 9126 Quality Model Mapping

```text
ISO 9126 Quality Model → cpm Checks

Functionality      → security, api_security, pii, dangerous
  - Suitability    → feature tests
  - Accuracy       → unit tests
  - Interoperability → imports, deps_placement
  - Security       → secrets, owasp, crypto, pii

Reliability        → dead_code, complexity, comments
  - Maturity       → test coverage
  - Fault tolerance→ dangerous patterns
  - Recoverability → error handling (future)

Usability          → a11y, inclusivity
  - Understandability → comments, dead_docs
  - Learnability   → documentation (future)
  - Operability    → slop, code_smells

Efficiency         → performance, filesize
  - Time behavior  → performance check
  - Resource util. → filesize, complexity

Maintainability    → todo, dead_docs, slop, crypto
  - Analyzability  → complexity, comments
  - Changeability  → portability, version_pins
  - Stability      → circular deps, dead_code
  - Testability    → test coverage (future)

Portability        → portability, version_pins
  - Adaptability   → portability check
  - Installability → (future)
  - Co-existence   → lockfile, deps_placement
  - Replaceability → version_pins
```

### Maturity-Growth Model

```text
Level 0: Code → ADR (basic traceability)
    └─ Every file has @see to at least one ADR

Level 1: + Unit tests (per feature)
    └─ Each feature has corresponding *_test.cpp
    └─ Test traces to code via file naming

Level 2: + E2E tests (per acceptance criteria)
    └─ Each ADR's "Acceptance criteria" section has test
    └─ E2E test file references ADR

Level 3: + ISO 9126 quality metrics
    └─ All 6 quality characteristics have at least 1 check
    └─ Quality metrics in ADR header

Level 4: + Full traceability matrix
    └─ All artifacts cross-linked
    └─ Coverage reports for every quality characteristic
```

### Acceptance Criteria Traceability

```cpp
// In ADR: Acceptance criteria section
## Acceptance Criteria
- [ ] User can create project (see test_e2e_project.cpp)
- [ ] Config is validated (see test_unit_config.cpp)
- [ ] Errors are logged (see test_unit_errors.cpp)
```

```cpp
// In E2E test file
/**
 * @file test_e2e_project.cpp
 * @brief E2E test for project creation
 * @see ADR-022-native-cpp-architecture.md
 * @see test_unit_config.cpp
 */
```

## Consequences

### Positive

- Clear scope prevents traceability bloat
- Focus on stable artifacts = meaningful links
- ISO 9126 provides proven quality framework
- Maturity levels allow gradual adoption

### Negative

- Some traceability gaps (tickets not linked)
- Requires discipline to add test references
- ISO 9126 may be overkill for small projects

## Implementation

1. Add `test-unit` naming convention to ADR template
2. Add E2E test reference pattern to ADR template
3. Add ISO 9126 section to ADR template
4. Add `cpm quality` command (future)
5. Add maturity level detection (future)

## References

- [ISO/IEC 9126](https://en.wikipedia.org/wiki/ISO/IEC_9126)
- [ADR-126: Traceability by Design](adr-126-traceability-by-design.md)
- [V-model designs](../designs/v-model-level-0.6.drawio)
