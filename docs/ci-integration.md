# CI/CD Integration

## GitHub Actions

```yaml
# .github/workflows/quality.yml
name: Quality
on: [push, pull_request]
jobs:
  cpm:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rkristelijn/cpm@main
```

With options:

```yaml
      - uses: rkristelijn/cpm@main
        with:
          path: './src'
```

## GitLab CI/CD Component

```yaml
# .gitlab-ci.yml
include:
  - component: gitlab.com/rkristelijn/cpm/scan@main

stages: [test]
```

With options:

```yaml
include:
  - component: gitlab.com/rkristelijn/cpm/scan@main
    inputs:
      stage: test
      path: './src'
```

## Manual (any CI)

```yaml
# Works in any CI system: Jenkins, Azure DevOps, Bitbucket, CircleCI, etc.
- curl -fsSL https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh | bash
- cpm scan .
```
