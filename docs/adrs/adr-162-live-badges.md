# ADR-162: Live Badges — All README Badges Must Be Pipeline-Verified

## Status

Accepted (2026-07-29)

## Context

The README currently has a mix of static (hardcoded) and semi-live badges. Static badges go stale — the test count says "131 passed" while the actual count is 193. Users clicking a badge get no evidence of the claim.

**Principle:** Every badge is a verifiable claim. If you click it, you see the proof.

## Decision

All README badges must be:

1. **Live** — updated automatically by CI on every merge to main
2. **Clickable** — links to the pipeline run, dashboard, or artifact that proves the claim
3. **Accurate** — values come from actual tool output, never hardcoded

### Badge Inventory

| Badge | Source of Truth | Click Target | Automation |
|-------|----------------|--------------|------------|
| maturity - level N | `cpm score` output | CI job log (self-check step) | Parse score → level mapping |
| tests - N passed | `make test-unit` doctest output | CI job log (test step) | Sum `passed` from all test runners |
| checks - N | `cpm scan` output or rule count | CI job log (self-check step) | `cpm` reports total checks available |
| languages - N | Count of `checks/*/` directories | CI job log | `ls -d checks/*/` |
| Quality Gate | SonarCloud API | SonarCloud dashboard | Already live ✅ |
| license | GitHub API | LICENSE file | Already live (shields.io) ✅ |
| release | GitHub API | Releases page | Already live (shields.io) ✅ |
| downloads | GitHub API | Releases page | Already live (shields.io) ✅ |
| homebrew | Homebrew tap existence | Tap repo or install docs | Verify tap exists in CI |
| apt/ppa | PPA existence | PPA page | Verify PPA exists in CI |
| install - curl | install.sh exit code | install.sh source | Smoke test in CI |

### Level Mapping (maturity badge)

| Score | Level | Color |
|-------|-------|-------|
| 0–25 | 1 | red |
| 26–50 | 2 | orange |
| 51–75 | 3 | yellow |
| 76–90 | 4 | green |
| 91–100 | 5 | brightgreen |

### Implementation

The `update-badges` CI job (runs on merge to main) will:

1. Build cpm
2. Run `make test-unit` → parse total passed tests
3. Run `cpm score` → extract score and level
4. Run `cpm scan . --depth 1` → extract check count
5. Count `checks/*/` directories → language count
6. Verify `brew install rkristelijn/tap/cpm` succeeds (or tap repo exists)
7. Verify PPA package exists via `apt-cache show`
8. Verify `curl -fsSL .../install.sh | bash` exits 0 in a clean container
9. Update README badges with actual values
10. Commit + push

### Badge URL Format

Use shields.io static badges for values we control, with links to proof:

```markdown
[![tests](https://img.shields.io/badge/tests-193%20passed-brightgreen)](https://github.com/rkristelijn/cpm/actions/workflows/ci.yml)
[![maturity](https://img.shields.io/badge/maturity-level%203-yellow)](https://github.com/rkristelijn/cpm/actions/workflows/ci.yml)
[![checks](https://img.shields.io/badge/checks-136-blue)](https://github.com/rkristelijn/cpm/actions/workflows/ci.yml)
```

For distribution badges, link to actual install verification:

```markdown
[![homebrew](https://img.shields.io/badge/homebrew-tap-orange)](https://github.com/rkristelijn/homebrew-tap)
[![apt](https://img.shields.io/badge/apt-ppa:rkristelijn/cpm-blue)](https://launchpad.net/~rkristelijn/+archive/ubuntu/cpm)
```

### Badges That Cannot Be Fully Automated Yet

| Badge | Reason | Interim |
|-------|--------|---------|
| homebrew | Requires tap repo verification | Check tap repo exists via GitHub API |
| apt/ppa | Requires Launchpad API | Check PPA page returns 200 |
| curl install | Requires clean container | Run install.sh in CI (already done in smoke test) |

## Consequences

- `scripts/update-badges.sh` must be rewritten to use actual tool output
- All badges become clickable links to CI
- Stale badge values become impossible
- CI job adds ~10s (running cpm score + counting)
- README badges are always in sync with the last main build
