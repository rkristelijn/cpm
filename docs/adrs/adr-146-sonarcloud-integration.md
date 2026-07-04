---
summary: SonarCloud as CI-side quality validation complementing cpm's local-first checks.
status: accepted
---

# ADR-146: SonarCloud Integration

## Context

cpm provides shift-left quality checks that run locally (pre-commit, pre-push). However, some quality dimensions are hard to measure locally:

- **Test coverage** — requires instrumented builds (gcov/lcov for C++, c8/istanbul for JS)
- **Duplication detection** — needs cross-file token analysis at scale
- **Security hotspots** — deep taint analysis beyond pattern matching
- **Trend tracking** — historical quality data across PRs

We needed a CI-side complement that validates what cpm catches locally, adds coverage metrics, and provides a public quality dashboard for the OSS project.

## Decision

Use SonarCloud (free for OSS) as the CI-side quality gate.

### Why SonarCloud

| Criterion | SonarCloud | Alternatives |
|-----------|-----------|--------------|
| Cost for OSS | Free | Codecov (free), CodeClimate (limited free) |
| C++ support | Yes (cfamily) | Codecov (coverage only, no SAST) |
| PR decoration | Yes (comments, status check) | Codecov (coverage only) |
| Quality gate | Configurable (coverage, duplication, bugs) | Limited |
| Dashboard | Public URL, badges | Varies |

### How it fits

```text
Developer machine (shift-left)     │  CI (validation)
───────────────────────────────────│──────────────────────────
cpm check --fast (pre-commit)      │
  → format, secrets, build         │
                                   │
cpm check (pre-push)               │
  → lint, complexity, tests        │
                                   │
                                   │  GitHub Actions:
                                   │    1. build (linux + macos)
                                   │    2. make coverage → lcov
                                   │    3. sonar-scanner uploads
                                   │    4. SonarCloud quality gate
                                   │
                                   │  SonarCloud checks:
                                   │    - coverage on new code ≥ 80%
                                   │    - no new bugs
                                   │    - no new vulnerabilities
                                   │    - duplication < 3%
```

cpm does 80% locally (instant feedback). SonarCloud validates in CI and adds what's hard to do locally.

### `scripts/sonar-download.sh`

Downloads SonarCloud findings via the public API so you can query them locally without the web UI:

```bash
# Download findings for current project
bash scripts/sonar-download.sh

# Download for specific project
bash scripts/sonar-download.sh rkristelijn_flupke
```

This enables `cpm findings --source sonar` in the future — pulling remote findings into the local findings database.

## Prior art: flupke

The pattern was first established in [flupke](https://github.com/rkristelijn/flupke):

- `sonar-project.properties` with exclusions for vendored/test code
- CI uploads coverage (lcov) → SonarCloud analyzes
- Quality gate on PRs (coverage ≥ 80%, no new bugs)
- Intentional suppressions documented with rationale (e.g., S4784 for regex libraries)

cpm follows the same pattern, adapted for C++:

| | flupke | cpm |
|---|--------|-----|
| Language | JavaScript | C++ |
| Coverage tool | c8 → lcov | gcov → lcov → coverage.xml |
| Exclusions | test/bench/vendored | vendor/build/.tmp/commands |
| Suppressions | S4784 (regex libs) | CPD for struct arrays |

## Consequences

- PRs get automatic quality feedback (SonarCloud comment)
- Coverage gaps are visible (issue #46 tracks fixing the gate)
- Public badge on README shows quality status
- `sonar-download.sh` bridges remote findings to local workflow
- Developers can ignore SonarCloud locally — cpm catches most issues first

## References

- @see sonar-project.properties (configuration)
- @see .github/workflows/ci.yml (sonar job)
- @see scripts/sonar-download.sh (API download tool)
- @see docs/issues/closed/configure-github-secrets-and-free-oss-integrations.md
- @see <https://sonarcloud.io/dashboard?id=rkristelijn_cpm>
