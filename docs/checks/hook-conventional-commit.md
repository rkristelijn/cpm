# hook-conventional-commit

## What it catches

Commit messages that don't follow Conventional Commits format.

## Why it matters

Conventional Commits enable automatic changelog generation, semantic versioning, and clear git history. Without them, understanding why a change was made requires reading the diff. Consistent commit messages also make `git log`, `git blame`, and bisecting much more useful.

## Examples

```text
# Bad
fixed stuff
update
WIP

# Good
feat(auth): add OAuth2 login flow
fix(api): handle null response from /users
docs(hooks): add check documentation
```

## Override

- Global: `cpm hook --global --disable conventional-commit`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  conventional-commit = false
  ```

- One commit: `git commit --no-verify`
