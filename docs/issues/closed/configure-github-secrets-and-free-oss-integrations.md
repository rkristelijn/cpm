---
title: configure GitHub secrets and free OSS integrations
type: chore
created: 2026-05-19T08:32:00+00:00
labels: [chore, ci]
remote:
---

## What

Set up remaining secrets and install free GitHub Apps:

1. `gh secret set SONAR_TOKEN` (same token as llama-cli, from sonarcloud.io)
2. Install CodeRabbit GitHub App on repo
3. Optionally: Snyk, FOSSA, OpenSSF Scorecard

## Done when

- [ ] `SONAR_TOKEN` secret set
- [ ] SonarCloud analysis runs in CI (green)
- [ ] CodeRabbit reviews PRs automatically
