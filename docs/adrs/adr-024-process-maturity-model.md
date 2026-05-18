---
summary: Progressive process maturity model — CMMI as coarse-grained kapstok, sub-levels as individual growth steps.
status: proposed
---

# ADR-024: Progressive Process Maturity Model

## Context

cpm checks *code quality* but not *process quality*. The simplest workflow is `code → push`. Every step we add reduces risk but adds overhead. This ADR defines a progressive model with CMMI (5 levels) as the coarse-grained framework, and sub-levels (1.1, 1.2, 2.1, etc.) as concrete growth steps that cpm can detect and encourage.

## Decision

CMMI levels are the kapstok (coat rack). Each CMMI level contains 2-4 sub-levels representing individual growth steps. Sub-levels are ordered: you complete them sequentially within a CMMI level before advancing.

## The Model

```text
CMMI 1 (Initial)        → 1.1 Cowboy, 1.2 Tracked
CMMI 2 (Managed)        → 2.1 Reviewed, 2.2 Verified, 2.3 Planned
CMMI 3 (Defined)        → 3.1 Standardized, 3.2 Measured
CMMI 4 (Quant. Managed) → 4.1 Optimized, 4.2 Data-Driven
CMMI 5 (Optimizing)     → 5.1 Governed, 5.2 Self-Improving
```

---

## CMMI Level 1 — Initial (Ad-hoc, Chaotic)

CMMI says: "Processes are unpredictable, poorly controlled, and reactive."

### 1.1 — Cowboy

**Workflow:** `code → push to main`

| Characteristic | Description |
|---------------|-------------|
| Process | None. Direct commits to main. |
| Tracking | No tickets, no traceability |
| Quality | "It works on my machine" |
| Risk | Maximum — no safety net |

**Framework mapping:** KMM 0 (Oblivious) · Agile Fluency: Pre-Agile · DORA: unmeasured

**What cpm detects:**

- All commits go to main directly
- No ticket references in commit messages
- No test files exist
- No CI pipeline

**cpm action:** Detect and suggest 1.2. Never block.

---

### 1.2 — Tracked

**Workflow:** `ticket → code → push`

**What's added:** Work visibility. Every change has a reason.

| Characteristic | Description |
|---------------|-------------|
| Process | Commits reference tickets |
| Tracking | Work visible on board (Kanban/backlog) |
| Quality | Auto-formatting on commit |
| Security | Secrets scanning (non-blocking) |

**Framework mapping:** KMM 1 (Emerging) · Agile Fluency: Early Focusing · DORA: Low

**What cpm detects:**

- Commit messages match `[A-Z]+-\d+` or `#\d+` or conventional commits
- README exists
- Formatting applied
- No secrets in code

**cpm enforcement at each level:**

- `learn`: "Your last 3 commits don't reference a ticket"
- `guide`: Warn on push if >50% commits lack ticket refs
- `guard`: Block push without ticket reference
- `enforce`: Block commit without ticket reference

---

## CMMI Level 2 — Managed (Project-Level Discipline)

CMMI says: "Projects are planned, performed, measured, and controlled." Process areas: Requirements Management, Project Planning, Configuration Management, Measurement & Analysis, Quality Assurance.

### 2.1 — Reviewed

**Workflow:** `ticket → branch → code → review → merge`

**What's added:** Branching + peer review. Configuration management begins.

| Characteristic | Description |
|---------------|-------------|
| Process | Feature branches, pull requests |
| Review | At least one reviewer approves |
| Config mgmt | Branch protection on main |
| CI | Basic pipeline (build + lint) |

**CMMI process areas addressed:**

- Configuration Management (CM) → branching, branch protection
- Quality Assurance (PPQA) → peer review as quality gate
- Requirements Management (REQM) → ticket-linked branches

**Framework mapping:** KMM 2 (Defined) · Agile Fluency: Focusing · DORA: Low→Medium · OpenSSF: Branch-Protection, Code-Review

**What cpm detects:**

- No direct commits to main (`git log main --no-merges`)
- Branch naming follows convention
- PRs have reviewers (merge commit metadata)
- CI pipeline exists (`.github/workflows/`, `Jenkinsfile`, etc.)
- PR size reasonable (<400 lines)
- No long-lived branches (>7 days)

---

### 2.2 — Verified

**Workflow:** `ticket + AC → branch → code + tests → CI green → review → merge`

**What's added:** Acceptance criteria, automated tests, CI quality gates.

| Characteristic | Description |
|---------------|-------------|
| Requirements | Tickets have acceptance criteria |
| Testing | Unit tests required for new code |
| CI | Tests + lint + security scan on every PR |
| Coverage | Tracked (not necessarily gated) |
| Commits | Conventional commits enforced |

**CMMI process areas addressed:**

- Requirements Management (REQM) → acceptance criteria
- Quality Assurance (PPQA) → automated test gates
- Measurement & Analysis (MA) → coverage tracking

**Framework mapping:** KMM 3 (Managed) · Agile Fluency: Delivering · DORA: Medium · DSOMM Level 2

**What cpm detects:**

- Tests exist for new/changed code (co-located `*.test.*`)
- CI passes before merge
- Coverage reported (lcov/cobertura file exists)
- Coverage doesn't decrease between commits
- Security scan in CI config
- No TODO/FIXME without ticket reference
- CHANGELOG updated per release

---

### 2.3 — Planned

**Workflow:** `sprint planning → sized tickets → branch → code + tests → CI → review → merge → retro`

**What's added:** Time-boxed iterations, estimation, retrospectives.

| Characteristic | Description |
|---------------|-------------|
| Planning | Work in sprints (1-2 weeks) |
| Estimation | Tickets sized (points or t-shirt) |
| Monitoring | Velocity tracked |
| Improvement | Retrospectives happen |
| Tech debt | Tracked and allocated time |

**CMMI process areas addressed:**

- Project Planning (PP) → sprint planning, estimation
- Project Monitoring & Control (PMC) → velocity, burndown
- Measurement & Analysis (MA) → velocity metrics

**Framework mapping:** KMM 4 (Quantitatively Managed) · Agile Fluency: Delivering+ · DORA: Medium→High

**What cpm detects:**

- Sprint cadence in commit frequency patterns
- DORA deployment frequency (merge/tag rate)
- DORA lead time (first commit → merge)
- DORA change failure rate (reverts / merges)
- WIP: concurrent open PRs per person
- Release notes exist per tag

---

## CMMI Level 3 — Defined (Organizational Standardization)

CMMI says: "Processes are well characterized and understood, described in standards, procedures, tools, and methods." Process areas: Organizational Process Definition, Organizational Training, Integrated Project Management, Risk Management, Decision Analysis.

### 3.1 — Standardized

**Workflow:** `roadmap → specs → sprint → branch → code + tests → CI → review → merge → deploy`

**What's added:** Org-wide standards, specifications, risk management, ADRs.

| Characteristic | Description |
|---------------|-------------|
| Standards | Documented coding standards, DoD |
| Specs | Functional + technical specs for epics |
| Risk | Risk register maintained |
| Decisions | ADRs for architectural choices |
| Training | Onboarding docs, CONTRIBUTING.md |
| Deployment | Automated, repeatable deploys |

**CMMI process areas addressed:**

- Organizational Process Definition (OPD) → documented standards
- Organizational Training (OT) → onboarding, CONTRIBUTING.md
- Integrated Project Management (IPM) → specs before implementation
- Risk Management (RSKM) → risk register
- Decision Analysis & Resolution (DAR) → ADRs

**Framework mapping:** KMM 5 (Optimizing) · Agile Fluency: Optimizing · DORA: High · DSOMM Level 3

**What cpm detects:**

- ADRs exist and are current (file freshness)
- Specs exist for epics (doc existence)
- CONTRIBUTING.md exists
- Deployment pipeline exists (CD config)
- Incident response plan exists
- Post-mortems after reverts
- Architecture documented (C4 or equivalent)
- Traceability matrix maintained (`cpm trace`)
- SAST runs in CI

---

### 3.2 — Measured

**Workflow:** previous + `→ measure → improve`

**What's added:** Systematic measurement, trend analysis, performance baselines.

| Characteristic | Description |
|---------------|-------------|
| DORA | All 4 metrics tracked and trended |
| Quality | Mutation testing for test effectiveness |
| Performance | Benchmarks tracked, no regression |
| Dependencies | Freshness tracked, SBOM generated |
| Security | SAST + DAST in pipeline |
| Compliance | GDPR/ISO 27001 checks if applicable |

**CMMI process areas addressed:**

- Measurement & Analysis (MA) → DORA trends, quality metrics
- Organizational Process Focus (OPF) → improvement based on data

**Framework mapping:** Agile Fluency: Optimizing · DORA: High→Elite · DSOMM Level 3-4

**What cpm detects:**

- DORA metrics trended over time
- Mutation score above threshold
- Performance benchmarks tracked (result files)
- No performance regression (comparison)
- Dependency freshness (version comparison)
- SBOM generated
- Feature coverage (requirements → tests)
- Compliance docs exist per framework

---

## CMMI Level 4 — Quantitatively Managed (Statistical Control)

CMMI says: "Quantitative objectives for quality and process performance are established and used as criteria in managing processes." Process areas: Organizational Process Performance, Quantitative Project Management.

### 4.1 — Optimized

**Workflow:** previous + statistical process control + predictive planning

**What's added:** Quantitative goals, statistical baselines, predictive capacity.

| Characteristic | Description |
|---------------|-------------|
| Baselines | Statistical process performance baselines |
| Prediction | Capacity planning from historical data |
| Quality gates | Quantitative thresholds (not just pass/fail) |
| SLOs | Service level objectives defined and tracked |
| Monitoring | Uptime, latency, error rate dashboards |

**CMMI process areas addressed:**

- Organizational Process Performance (OPP) → baselines, models
- Quantitative Project Management (QPM) → statistical management

**Framework mapping:** KMM 5-6 · Agile Fluency: Optimizing · DORA: Elite · ITIL: Change Enablement

**What cpm detects:**

- SLOs defined (config/doc existence)
- Monitoring configured (config files)
- Velocity prediction accuracy (estimate vs actual)
- Quality trend stable or improving
- Change categorization (standard/normal/emergency)
- Roadmap estimation accuracy

---

### 4.2 — Data-Driven

**Workflow:** previous + automated decision support + proactive optimization

**What's added:** Data drives decisions, not opinions. Proactive problem prevention.

| Characteristic | Description |
|---------------|-------------|
| Analytics | Code health trends, hotspot detection |
| Proactive | Tech debt prioritized by impact data |
| Experiments | A/B testing, feature flags |
| Cost | Cost of delay quantified |
| Supply chain | SLSA provenance, signed artifacts |

**CMMI process areas addressed:**

- Quantitative Project Management (QPM) → data-driven prioritization
- Organizational Process Performance (OPP) → process models

**Framework mapping:** DORA: Elite · Platform Engineering Level 4

**What cpm detects:**

- SLSA provenance generated
- Feature flags in use (config detection)
- Tech debt prioritized by churn × complexity
- Hotspot analysis available
- Signed releases/artifacts

---

## CMMI Level 5 — Optimizing (Continuous Improvement)

CMMI says: "Focus on continually improving process performance through incremental and innovative process and technological improvements." Process areas: Causal Analysis & Resolution, Organizational Performance Management.

### 5.1 — Governed

**Workflow:** `strategy → architecture review → roadmap → specs → sprint → build → deploy → measure → learn → feed back`

**What's added:** Cross-team governance, architecture review, organizational alignment.

| Characteristic | Description |
|---------------|-------------|
| Architecture | Architecture Review Board (lightweight, async) |
| Governance | Change Advisory Board for high-risk changes |
| Cross-team | Dependency management, inner-source |
| Platform | Shared platform services (Team Topologies) |
| Compliance | Compliance-as-code, automated policies |
| Resilience | DR tested, chaos engineering |

**CMMI process areas addressed:**

- Causal Analysis & Resolution (CAR) → post-mortems, root cause
- Organizational Performance Management (OPM) → cross-team improvement

**Framework mapping:** KMM 6 (Congruent) · Agile Fluency: Strengthening · ITIL: Full ITSM · Team Topologies: all 4 types

**What cpm detects:**

- Cross-team deps documented
- DR plan exists and tested (evidence)
- Compliance-as-code policies exist
- Audit trail complete (JSONL history)
- Risk register maintained and fresh
- Observability configured (tracing)

---

### 5.2 — Self-Improving

**Workflow:** previous + autonomous improvement + innovation cycles

**What's added:** The organization improves itself. Innovation is systematic.

| Characteristic | Description |
|---------------|-------------|
| Learning | Cross-team retros, guilds, communities of practice |
| Innovation | Innovation time allocated, experiments tracked |
| Autonomy | Teams self-select improvements |
| Feedback | Customer feedback loops automated |
| Evolution | Process itself evolves based on data |

**CMMI process areas addressed:**

- Organizational Performance Management (OPM) → systematic innovation
- Causal Analysis & Resolution (CAR) → prevent recurrence

**Framework mapping:** Agile Fluency: Strengthening · Beyond Budgeting · Sociocracy

**What cpm detects:**

- Innovation/experiment tickets exist
- Cross-team retro docs exist
- Process changes tracked (cpm.toml history)
- Customer feedback mechanism exists
- Improvement rate (findings resolved / findings created)

---

## Summary: The Complete Progression

```text
CMMI 1 ─ Initial
  1.1  code → push                              (Cowboy)
  1.2  ticket → code → push                     (Tracked)

CMMI 2 ─ Managed
  2.1  ticket → branch → review → merge         (Reviewed)
  2.2  ticket+AC → branch+test → CI → review    (Verified)
  2.3  plan → size → sprint → build → retro     (Planned)

CMMI 3 ─ Defined
  3.1  roadmap → spec → build → deploy          (Standardized)
  3.2  + measure → trend → improve              (Measured)

CMMI 4 ─ Quantitatively Managed
  4.1  + SLOs → baselines → predict             (Optimized)
  4.2  + data-driven decisions → supply chain    (Data-Driven)

CMMI 5 ─ Optimizing
  5.1  + governance → architecture → compliance  (Governed)
  5.2  + self-improving → innovation → evolve    (Self-Improving)
```

## Key Question Answered per Sub-Level

| Sub-level | Dimension Added | Key Question |
|-----------|----------------|--------------|
| 1.1 → 1.2 | Work tracking | "Waarom doen we dit?" |
| 1.2 → 2.1 | Peer review | "Is dit goed genoeg?" |
| 2.1 → 2.2 | Quality gates | "Werkt dit echt?" |
| 2.2 → 2.3 | Predictability | "Wanneer is dit klaar?" |
| 2.3 → 3.1 | Standardization | "Doen we het overal hetzelfde?" |
| 3.1 → 3.2 | Measurement | "Worden we beter?" |
| 3.2 → 4.1 | Statistical control | "Kunnen we voorspellen?" |
| 4.1 → 4.2 | Data-driven | "Wat zeggen de data?" |
| 4.2 → 5.1 | Governance | "Zijn we aligned cross-team?" |
| 5.1 → 5.2 | Self-improvement | "Verbetert het systeem zichzelf?" |

## Complete Framework Mapping

| cpm | CMMI | KMM | Agile Fluency | DORA | DSOMM | ITIL |
|-----|------|-----|---------------|------|-------|------|
| 1.1 | 1 | 0 | Pre-Agile | — | 0 | — |
| 1.2 | 1 | 1 | Early Focusing | Low | 1 | — |
| 2.1 | 2 | 2 | Focusing | Low-Med | 1-2 | — |
| 2.2 | 2 | 3 | Delivering | Medium | 2 | — |
| 2.3 | 2 | 4 | Delivering+ | Med-High | 2 | — |
| 3.1 | 3 | 5 | Optimizing | High | 3 | Change Enablement |
| 3.2 | 3 | 5 | Optimizing | High-Elite | 3-4 | + Problem Mgmt |
| 4.1 | 4 | 5-6 | Optimizing | Elite | 4 | Full Change + SLM |
| 4.2 | 4 | 6 | Optimizing | Elite | 4 | + Capacity Mgmt |
| 5.1 | 5 | 6 | Strengthening | Elite+ | 4 | Full ITSM |
| 5.2 | 5 | 6 | Strengthening | Elite+ | 4 | + CSI |

## When to Introduce What

| Practice | Sub-level | Why here |
|----------|-----------|----------|
| Auto-formatting | 1.2 | Zero cost, immediate benefit |
| Secrets scanning | 1.2 | Non-negotiable baseline |
| Ticket references | 1.2 | Traceability starts |
| Branching | 2.1 | Prerequisite for review |
| Code review | 2.1 | Peer accountability |
| Branch protection | 2.1 | Enforce review process |
| CI pipeline | 2.1-2.2 | Automate what you'd forget |
| Acceptance criteria | 2.2 | Define "done" before starting |
| Unit tests | 2.2 | Prove it works |
| Security scanning (SAST) | 2.2 | Shift-left security |
| Coverage tracking | 2.2 | Know your blind spots |
| Sprint planning | 2.3 | Sustainable pace |
| Estimation | 2.3 | Predictability |
| Velocity tracking | 2.3 | Know your capacity |
| Retrospectives | 2.3 | Continuous improvement |
| Tech debt allocation | 2.3 | Prevent rot |
| DORA metrics | 2.3 | Measure delivery performance |
| WIP limits | 2.3 | Focus and flow |
| Roadmap | 3.1 | Strategic alignment |
| Functional specs | 3.1 | Reduce rework |
| Technical specs | 3.1 | Reduce surprises |
| ADRs | 3.1 | Decision traceability |
| Automated deployment | 3.1 | Repeatable releases |
| Post-mortems | 3.1 | Learn from failures |
| Mutation testing | 3.2 | Test quality, not just coverage |
| Performance benchmarks | 3.2 | Prevent regression |
| DAST | 3.2 | Runtime security |
| Traceability matrix | 3.2 | Requirements → tests |
| SBOM | 3.2 | Supply chain visibility |
| SLOs/SLAs | 4.1 | Service level commitments |
| Statistical baselines | 4.1 | Predictive capacity |
| Uptime monitoring | 4.1 | Production understanding |
| Change categorization | 4.1 | Risk-based deployment |
| Feature flags | 4.2 | Safe experimentation |
| SLSA provenance | 4.2 | Supply chain security |
| Hotspot analysis | 4.2 | Data-driven tech debt |
| Architecture Review Board | 5.1 | Cross-team consistency |
| Change Advisory Board | 5.1 | High-risk governance |
| Disaster recovery testing | 5.1 | Resilience verification |
| Compliance-as-code | 5.1 | Automated governance |
| Observability (tracing) | 5.1 | Production understanding |
| Cross-team retros | 5.2 | Organizational learning |
| Innovation allocation | 5.2 | Systematic improvement |

## Automation Potential

| Sub-level | % Automatable | What needs humans |
|-----------|--------------|-------------------|
| 1.1 | 100% | Detection only |
| 1.2 | 95% | Ticket creation itself |
| 2.1 | 85% | Review quality (not just existence) |
| 2.2 | 90% | AC quality, test meaningfulness |
| 2.3 | 60% | Sprint planning, estimation, retros |
| 3.1 | 50% | Spec writing, roadmap decisions |
| 3.2 | 70% | Threshold setting, trend interpretation |
| 4.1 | 40% | Baseline interpretation, SLO negotiation |
| 4.2 | 50% | Experiment design, prioritization |
| 5.1 | 30% | Architecture decisions, governance |
| 5.2 | 20% | Innovation, organizational change |

## How cpm Implements This

### Detection

```bash
$ cpm maturity --process

  Process Maturity: 2.2 (Verified)
  ─────────────────────────────────
  ✓ 1.2  Tickets referenced (87% of commits)
  ✓ 2.1  PRs used (94% of changes)
  ✓ 2.2  Tests exist (78% of new code)
  ✗ 2.3  No sprint cadence detected
  ✗ 2.3  DORA lead time: 5 days (target: <1 day)

  Next step → 2.3 (Planned):
    → Establish sprint cadence
    → Track DORA metrics (cpm enable dora)
    → Add retrospective docs
```

### Configuration

```toml
# cpm.toml
[process]
level = "2.2"              # enforce up to this sub-level
target = "3.1"             # show guidance toward this

[process.checks]
ticket-reference = "guard"   # 1.2
branch-required = "guard"    # 2.1
review-required = "guard"    # 2.1
tests-required = "guard"     # 2.2
ci-green = "enforce"         # 2.2
coverage-decrease = "guide"  # 2.2
dora-metrics = "learn"       # 2.3
sprint-cadence = "learn"     # 2.3
```

### Design Principles

1. **CMMI is the kapstok** — coarse-grained levels provide industry credibility and clear progression
2. **Sub-levels are the growth steps** — concrete, actionable, one dimension at a time
3. **Each sub-level is a valid choice** — not every team needs 5.2
4. **Never block without teaching** — every finding explains WHY and HOW
5. **Automate detection, suggest adoption** — cpm detects your level automatically
6. **Evidence over ceremony** — check for *evidence* (PR exists, test exists, retro doc exists), not specific rituals

## References

- @see docs/adrs/adr-012-maturity-framework-research.md
- @see docs/adrs/adr-013-product-positioning.md
- @see docs/adrs/adr-020-product-vision.md
- @see docs/adrs/adr-016-traceability-matrix.md
- @see docs/adrs/adr-014-findings-database.md

### External references

- CMMI Institute: <https://cmmiinstitute.com/>
- CMMI Wikipedia: <https://en.wikipedia.org/wiki/Capability_Maturity_Model_Integration>
- Agile Fluency Model: <https://martinfowler.com/articles/agileFluency.html>
- Kanban Maturity Model: <https://kanban.university/kanban-maturity-model/>
- DORA Metrics: <https://dora.dev/>
- OWASP DSOMM: <https://owasp.org/www-project-devsecops-maturity-model/>
- ITIL 4: <https://www.axelos.com/certifications/itil-service-management>
- Team Topologies: <https://teamtopologies.com/>
- CNCF Platform Engineering Maturity Model: <https://maturitymodel.cncf.io/>
- Minware Scorecard: <https://www.minware.com/blog/full-team-health-scorecard>
- OpsLevel Service Maturity: <https://www.opslevel.com/product/maturity>
- OpenSSF Scorecard: <https://scorecard.dev/>
