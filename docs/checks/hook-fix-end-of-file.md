# hook-fix-end-of-file

## What it fixes

Ensures every staged text file ends with a newline character.

## Why it matters

POSIX defines a line as a sequence of characters ending with a newline. Files without a trailing newline cause `\ No newline at end of file` warnings in diffs, break concatenation (`cat a b`), and confuse some tools. Most editors and linters expect it.

## How it works

1. For each staged file (skipping binaries and empty files), checks if the last byte is a newline
2. If not, appends `\n` and re-stages with `git add`
3. Prints a summary of fixed files
4. Always exits 0 — autofix checks never block commits

## Override

- Global: `cpm hook --global --disable fix-end-of-file`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  fix-end-of-file = false
  ```

- One commit: `git commit --no-verify`
