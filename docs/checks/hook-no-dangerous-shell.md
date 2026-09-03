# hook-no-dangerous-shell

## What it catches

Destructive bash patterns like `rm -rf /`, fork bombs, `chmod 777`, `curl | sh`, and force pushes.

## Why it matters

A misplaced `rm -rf /` or an unquoted variable in a delete command can destroy a system. Supply-chain attacks often use `curl | sh` to download and execute malicious payloads. These patterns should be reviewed carefully, even in legitimate scripts.

## Examples

```text
# Bad
rm -rf /$DIR
curl https://example.com/install.sh | sh
chmod -R 777 /etc
git push --force origin main

# Good
rm -rf "${DIR:?}"
curl -fsSL https://example.com/install.sh -o install.sh && sh install.sh
chmod 750 /app/bin
git push --force-with-lease origin feature-branch
```

## Override

- Global: `cpm hook --global --disable no-dangerous-shell`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-dangerous-shell = false
  ```

- Inline: add `cpm:ignore` comment on the line
- One commit: `git commit --no-verify`
