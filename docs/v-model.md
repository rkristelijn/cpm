# cpm Quality Tiers — V-Model Visualization

## Level 0: Just Ship It (1D)

```text
  code ──────────────────────────────────────────────► deploy
```

No checks. YOLO. Most repos start here.

## Level 1: Build + Deploy (cpm check --fast)

```text
  code ──► format ──► build ──────────────────────────► deploy
```

**cpm tier 1**: format + compile. Pre-commit. <5 seconds.

## Level 2: V-Model Lite (cpm check)

```text
  Motivation          ◄─────────────────────────── Acceptance
       │                                               ▲
       ▼                                               │
  Design              ◄──────────────────────── Integration Test
       │                                               ▲
       ▼                                               │
  code ──► format ──► build ──► lint ──► unit test ────┘
```

**cpm tier 2**: + lint + test. Pre-push. <60 seconds.

## Level 3: Full V-Model (cpm check --full)

```text
  Business Value      ◄──────────────────────────── Value Delivered
       │                                                  ▲
       ▼                                                  │
  Requirements/ADR    ◄────────────────────────── Acceptance Test
       │                                                  ▲
       ▼                                                  │
  Architecture        ◄──────────────────────── Integration Test
       │                                                  ▲
       ▼                                                  │
  Design              ◄────────────────────────── E2E Test
       │                                                  ▲
       ▼                                                  │
  code ──► format ──► build ──► lint ──► SAST ──► coverage
```

**cpm tier 3**: + coverage + SAST + vulnerability scan. CI. Minutes.

## Level 4: Measured (cpm maturity)

```text
  Strategy/OKR        ◄──────────────────────────── DORA Metrics
       │                                                  ▲
       ▼                                                  │
  Business Value      ◄──────────────────────────── Value Delivered
       │                                                  ▲
       ▼                                                  │
  Requirements/ADR    ◄────────────────────────── Acceptance Test
       │                                                  ▲
       ▼                                                  │
  Architecture        ◄──────────────────────── Integration Test
       │              ┌─────────────────────────┐         ▲
       ▼              │  cpm enforces:          │         │
  Design              │  • ADR exists           │   E2E Test
       │              │  • Tests trace to reqs  │         ▲
       ▼              │  • Coverage gate        │         │
  code ──► format ──► │  • Complexity ≤ 10      │ ──► coverage
                      │  • No secrets           │
                      │  • License clean        │
                      │  • Deps pinned          │
                      └─────────────────────────┘
```

## Level 5: Optimized (auto-remediation)

```text
  Strategy            ◄──── DORA + Trends + Predictions
       │                              ▲
       ▼                              │
  Business Value      ◄──── Customer Feedback Loop
       │                              ▲
       ▼                              │
  Requirements        ◄──── Mutation Testing + Fuzzing
       │                              ▲
       ▼                              │
  Architecture        ◄──── Architecture Tests (import rules)
       │                              ▲
       ▼                              │
  code ──► AI auto-fix ──► all checks ──► auto-deploy
              │
              └── cpm format (auto)
              └── cpm findings → AI fix suggestion
              └── cpm report → stakeholder dashboard
```

## Framework Mapping

```text
┌─────────────────────────────────────────────────────────────┐
│                    cpm Quality Model                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─── ISO 25010 ───┐  ┌─── DORA ────┐  ┌── OpenSSF ──┐   │
│  │ Maintainability  │  │ Deploy Freq  │  │ Scorecard   │   │
│  │ Security         │  │ Lead Time    │  │ 18 checks   │   │
│  │ Reliability      │  │ Failure Rate │  │             │   │
│  │ Portability      │  │ Recovery     │  │             │   │
│  │ Performance      │  │              │  │             │   │
│  │ Usability        │  │              │  │             │   │
│  │ Compatibility    │  │              │  │             │   │
│  │ Functionality    │  │              │  │             │   │
│  └──────────────────┘  └──────────────┘  └─────────────┘   │
│                                                             │
│  ┌── 12-Factor ──┐  ┌── Diátaxis ──┐  ┌── OWASP ────┐    │
│  │ Config in env  │  │ Tutorial     │  │ Top 10       │    │
│  │ Stateless      │  │ How-to       │  │ SAST         │    │
│  │ Port binding   │  │ Reference    │  │ Secrets      │    │
│  │ Disposability  │  │ Explanation  │  │ Deps         │    │
│  └────────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  ┌── V-Model ────┐  ┌── CMMI ──────┐  ┌── Lean ─────┐    │
│  │ Define→Build   │  │ 5 levels     │  │ No waste     │    │
│  │ →Test→Release  │  │ Progressive  │  │ Flow         │    │
│  │ Left=Right     │  │ Measurable   │  │ Pull         │    │
│  └────────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## What cpm checks at each level

| Level | Left side (Define) | cpm check | Right side (Verify) |
|-------|-------------------|-----------|-------------------|
| 0 | — | — | — |
| 1 | — | format, build | — |
| 2 | — | + lint, test | unit test |
| 3 | ADR exists | + SAST, coverage | e2e test, acceptance |
| 4 | ADR + acceptance criteria | + DORA metrics | traceability matrix |
| 5 | Strategy + OKR | + auto-remediation | predictions + trends |

## AI Vibe-Coding Flow

```text
  Developer: "add user authentication"
       │
       ▼
  AI generates code ──────────────────────────┐
       │                                       │
       ▼                                       ▼
  cpm check --fast                      cpm findings
       │                                       │
       ├── ✗ format violation ──► AI auto-fix  │
       ├── ✗ secrets detected ──► BLOCK        │
       ├── ✗ complexity > 10 ──► AI refactor   │
       ├── ✓ build passes                      │
       │                                       │
       ▼                                       ▼
  cpm check (tier 2)                    AI reads findings
       │                                       │
       ├── ✗ no test ──► AI generates test     │
       ├── ✗ lint error ──► AI fixes           │
       ├── ✓ all pass                          │
       │                                       │
       ▼                                       │
  git push ◄───────────────────────────────────┘
```
