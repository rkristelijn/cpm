# hook-no-artifacts

## What it catches

Build artifacts and OS junk files: `.DS_Store`, `Thumbs.db`, `node_modules/`, `build/`, `dist/`, `__pycache__/`, `*.pyc`.

## Why it matters

These files are generated locally and should never be in version control. They bloat the repo, cause merge conflicts, and `node_modules/` alone can add hundreds of MB. `.DS_Store` files can leak directory structure information.

## Examples

```text
# Bad
git add .DS_Store
git add node_modules/
git add dist/bundle.js

# Good
echo ".DS_Store" >> .gitignore
echo "node_modules/" >> .gitignore
echo "dist/" >> .gitignore
```

## Override

- Global: `cpm hook --global --disable no-artifacts`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-artifacts = false
  ```

- One commit: `git commit --no-verify`
