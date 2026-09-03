# hook-no-missing-gitignore

## What it catches

Missing security-critical patterns in `.gitignore`: `.env`, `*.pem`, `*.key`.

## Why it matters

Without these patterns in `.gitignore`, it's only a matter of time before someone runs `git add .` and commits secrets, private keys, or environment files. The `.gitignore` is your last line of defense before secrets enter git history permanently.

## Examples

```gitignore
# Bad — .gitignore missing critical patterns
node_modules/
dist/

# Good — includes security patterns
node_modules/
dist/
.env
*.pem
*.key
```

## Override

- Global: `cpm hook --global --disable no-missing-gitignore`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-missing-gitignore = false
  ```

- One commit: `git commit --no-verify`
