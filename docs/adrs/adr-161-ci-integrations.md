# ADR-161: GitHub Action & GitLab CI Component

## Status

Accepted (2026-07-26)

## Context

cpm currently requires local installation (`brew`, `apt`, `curl | bash`). To reach teams that
don't want to install tools locally, cpm must be available as a one-click CI integration:

- **GitHub**: Actions Marketplace — users add `uses: rkristelijn/cpm-action@v1` to their workflow.
- **GitLab**: CI/CD Components — users add `include: component:` to their `.gitlab-ci.yml`.

Both platforms support "click to enable" in their web UI, which is the target UX.

## Decision

### GitHub Action (`rkristelijn/cpm-action`)

Composite action (not Docker) for speed:

```yaml
# action.yml
name: 'cpm quality gate'
description: 'Run cpm checks on your code'
branding:
  icon: 'check-circle'
  color: 'green'
inputs:
  level:
    description: 'Enforcement level (learn|guide|guard|enforce)'
    default: 'guide'
  tier:
    description: 'Check tier (fast|default|full)'
    default: 'default'
  rules:
    description: 'Run rule-scan (true|false)'
    default: 'true'
  version:
    description: 'cpm version to install'
    default: 'latest'
runs:
  using: 'composite'
  steps:
    - name: Install cpm
      shell: bash
      run: |
        curl -fsSL https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh | bash
    - name: Run cpm check
      shell: bash
      run: cpm check --${{ inputs.tier }}
    - name: Run rule-scan
      if: inputs.rules == 'true'
      shell: bash
      run: cpm rule-scan --junit > cpm-results.xml || true
    - name: Annotate PR
      if: always()
      shell: bash
      run: |
        # Parse findings and emit GitHub annotations
        cpm findings --github-annotations || true
```

User experience:
```yaml
# .github/workflows/quality.yml
on: [push, pull_request]
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rkristelijn/cpm-action@v1
        with:
          level: guard
```

### GitLab CI Component (`rkristelijn/cpm-component`)

```yaml
# templates/cpm.yml
spec:
  inputs:
    level:
      default: guide
    tier:
      default: default
---
cpm-quality:
  image: ubuntu:24.04
  before_script:
    - curl -fsSL https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh | bash
  script:
    - cpm check --$[[ inputs.tier ]]
    - cpm rule-scan --junit > cpm-results.xml
  artifacts:
    reports:
      junit: cpm-results.xml
```

User experience:
```yaml
include:
  - component: gitlab.com/rkristelijn/cpm-component/cpm@v1
    inputs:
      level: guard
```

### Output formats needed

Both integrations require:
1. `--junit` flag on `cpm check` and `rule-scan` → JUnit XML for CI artifact reporting
2. `--github-annotations` flag → `::warning file=X,line=Y::message` format
3. Exit code: 0 = pass, 1 = findings exceed threshold

### Versioning

- Action/component version tracks cpm version (v0.7.0 → cpm-action@v0.7)
- Major version tag (`@v1`) for semver stability
- `latest` resolves to most recent release

## Consequences

- New repo: `rkristelijn/cpm-action` (GitHub Action)
- New repo: `rkristelijn/cpm-component` (GitLab)
- cpm needs `--junit` and `--github-annotations` output modes (minor feature)
- install.sh must work non-interactively in CI (already does)
- Marketplace listing requires: README, icon, `action.yml` metadata
