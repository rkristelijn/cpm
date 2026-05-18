# cpm hook / unhook

Install or remove git hooks that run quality checks automatically.

## Usage

```bash
cpm hook      # install hooks based on cpm.toml
cpm unhook    # remove all cpm hooks
```

## What gets installed

| Hook | Trigger | Runs |
|------|---------|------|
| `pre-commit` | `git commit` | `cpm check --fast` |
| `pre-push` | `git push` | `cpm check` |
| `commit-msg` | `git commit` | conventional commit validation |

## Configuration

```toml
# cpm.toml
[hooks]
pre-commit = true    # format + build on commit
pre-push = true      # full check before push
commit-msg = false   # conventional commit enforcement
```

## How it works

Hooks are inline scripts written to `.git/hooks/`. No files are committed to the repo — cpm generates them from config.

```bash
# Generated .git/hooks/pre-commit:
#!/bin/sh
cpm check --fast
```

## Design decisions

- **Non-destructive**: won't overwrite existing hooks
- **No committed files**: hooks live in `.git/` only
- **Requires cpm globally**: hooks call `cpm` binary
- **Fast**: pre-commit target is <5s

## Related

- [check.md](check.md) — what the hooks run
- [enforcement-levels.md](enforcement-levels.md) — control blocking behavior
