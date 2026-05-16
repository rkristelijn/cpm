# Contributing

## Quick start

```bash
bash install.sh        # install cpm locally
cpm maturity           # check current level
```

## Code style

- Shell scripts: bash, `set -o errexit/nounset/pipefail`, shfmt -i 2
- Conventional commits: `type(scope): description`
- Comments explain WHY, not WHAT

## Workflow

1. Create feature branch
2. Make changes
3. `cpm check`
4. Push, create PR
