# hook-fix-trailing-whitespace

## What it fixes

Removes trailing whitespace (spaces, tabs) from the end of lines in staged files.

## Why it matters

Trailing whitespace creates noisy diffs, triggers linter warnings, and wastes bytes. Most style guides and editors flag it. Fixing it automatically means you never have to think about it.

## How it works

1. For each staged file (skipping binaries), runs `sed -i '' 's/[[:space:]]*$//'`
2. If the file changed, re-stages it with `git add`
3. Prints a summary of fixed files
4. Always exits 0 — autofix checks never block commits

## Override

- Global: `cpm hook --global --disable fix-trailing-whitespace`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  fix-trailing-whitespace = false
  ```

- One commit: `git commit --no-verify`
