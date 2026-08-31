# hook-no-wip-commit

## What it catches

Commit messages containing `WIP`, `wip`, `temp`, `fixup`, or `squash` on branches that track a remote.

## Why it matters

WIP commits on tracked branches will be pushed and show up in pull requests and shared history. They indicate incomplete work that should be squashed before sharing. On local-only branches, WIP commits are fine — this check only triggers on remote-tracking branches.

## Examples

```text
# Bad (on tracked branch)
git commit -m "WIP: half-done feature"
git commit -m "temp: testing something"
git commit -m "fixup: forgot a file"

# Good
git commit -m "feat(auth): add login form"
# Or squash WIP commits before push:
git rebase -i HEAD~3
```

## Override

- Global: `cpm hook --global --disable no-wip-commit`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-wip-commit = false
  ```

- One commit: `git commit --no-verify`
