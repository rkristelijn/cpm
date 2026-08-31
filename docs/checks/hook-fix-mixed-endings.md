# hook-fix-mixed-endings

## What it fixes

Normalizes files with CRLF line endings (`\r\n`) to Unix LF (`\n`).

## Why it matters

Mixed line endings cause noisy diffs, break shell scripts on Unix, and create merge conflicts. They typically happen when Windows and macOS/Linux developers edit the same file. This autofix replaces the `no-mixed-endings` warning check — instead of warning, it fixes and re-stages.

## How it works

1. For each staged file (skipping binaries), checks for CRLF bytes
2. If found, runs `sed -i '' 's/\r$//'` to strip carriage returns
3. Re-stages the fixed file with `git add`
4. Prints a summary of normalized files
5. Always exits 0 — autofix checks never block commits

When `fix-mixed-endings` is enabled, the `no-mixed-endings` warning check is automatically skipped to avoid duplicate reporting.

## Override

- Global: `cpm hook --global --disable fix-mixed-endings`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  fix-mixed-endings = false
  ```

- One commit: `git commit --no-verify`
