# hook-no-mixed-endings

## What it catches

Files with mixed line endings — some lines use CRLF (`\r\n`) and others use LF (`\n`).

## Why it matters

Mixed line endings cause noisy diffs, break shell scripts on Unix, and create merge conflicts. They typically happen when Windows and macOS/Linux developers edit the same file. A `.gitattributes` file with `* text=auto` prevents this at the git level.

## Examples

```text
# Bad — mixed endings in same file
line 1\n
line 2\r\n
line 3\n

# Good — consistent LF everywhere
line 1\n
line 2\n
line 3\n
```

Fix: `dos2unix <file>` or configure `.gitattributes`:

```gitattributes
* text=auto
*.sh text eol=lf
```

## Override

- Global: `cpm hook --global --disable no-mixed-endings`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-mixed-endings = false
  ```

- One commit: `git commit --no-verify`
