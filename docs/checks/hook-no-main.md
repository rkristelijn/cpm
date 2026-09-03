# hook-no-main

## What it catches

Direct commits on protected branches: `main`, `master`, and `develop`.

## Why it matters

Committing directly to main bypasses code review, CI checks, and branch protection rules. Even in solo projects, feature branches create a clean history and make it easy to revert changes. In team settings, direct pushes to main can break the build for everyone.

## Examples

```text
# Bad
git checkout main
git commit -m "fix: quick patch"

# Good
git checkout -b fix/quick-patch
git commit -m "fix: quick patch"
git push -u origin fix/quick-patch
```

## Override

- Global: `cpm hook --global --disable no-main`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-main = false
  ```

- One commit: `git commit --no-verify`
