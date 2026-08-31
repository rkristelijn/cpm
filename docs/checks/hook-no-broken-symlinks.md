# hook-no-broken-symlinks

## What it catches

Broken symbolic links (symlinks pointing to non-existent targets) in staged files.

## Why it matters

Broken symlinks cause runtime errors, failed builds, and confusing "file not found" issues. They often result from moving or deleting a target file without updating the symlink. Committing them spreads the problem to every developer who clones the repo.

## Examples

```text
# Bad
ln -s ../lib/old-utils.js utils.js  # old-utils.js was deleted
git add utils.js

# Good
ln -s ../lib/utils.js utils.js      # target exists
git add utils.js
```

## Override

- Global: `cpm hook --global --disable no-broken-symlinks`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-broken-symlinks = false
  ```

- One commit: `git commit --no-verify`
