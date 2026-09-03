# hook-no-empty-files

## What it catches

Zero-byte (empty) files being staged for commit.

## Why it matters

Empty files are usually accidental — created by a failed script, a mistyped `touch` command, or an incomplete merge. They add noise to the repo and can cause confusion when someone expects content. Intentional placeholder files should contain at least a comment explaining their purpose.

## Examples

```text
# Bad
touch src/utils.js    # 0 bytes, no content
git add src/utils.js

# Good
echo "// TODO: implement utility functions" > src/utils.js
git add src/utils.js
```

## Override

- Global: `cpm hook --global --disable no-empty-files`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-empty-files = false
  ```

- One commit: `git commit --no-verify`
