# hook-no-artifacts

## What it catches

Build artifacts, OS junk, IDE settings, runtime caches, logs, databases, temp files, and package manager directories that should never be in version control.

### OS junk

`.DS_Store`, `Thumbs.db`, `desktop.ini`, `._*` (macOS resource forks), `.Spotlight-V100`, `.Trashes`

### IDE settings

`.idea/*`, `.vscode/settings.json`, `.vscode/launch.json`, `*.suo`, `*.user`, `*.sln.docstates`

### Python runtime/build

`*.pyc`, `__pycache__/*`, `*.egg-info/*`, `.tox/*`, `.pytest_cache/*`, `.mypy_cache/*`, `venv/*`, `.venv/*`

### Node / JavaScript

`node_modules/*`, `.eslintcache`, `.tsbuildinfo`, `.nyc_output/*`, `coverage/*`, `bower_components/*`, `*.min.js.map`, `*.min.css.map`

### Build output

`build/*`, `dist/*`, `target/*`

### CSS cache

`.sass-cache/*`

### Package managers

`vendor/*`, `packages/*`, `.gradle/*`

### Logs & databases

`*.log`, `*.sqlite`, `*.sqlite3`, `*.sql.bak`, `*.dump`, `*.core`, `*.dmp`

### Temp / backup

`*.bak`, `*.old`, `*.orig`, `*.swp`, `*.swo`, `*~`

## Why it matters

These files are generated locally and should never be in version control. They bloat the repo, cause merge conflicts, and `node_modules/` alone can add hundreds of MB. `.DS_Store` files can leak directory structure information. IDE settings cause constant conflicts between team members.

## Examples

```text
# Bad
git add .DS_Store
git add node_modules/
git add dist/bundle.js
git add .idea/workspace.xml
git add debug.log

# Good
echo ".DS_Store" >> .gitignore
echo "node_modules/" >> .gitignore
echo "dist/" >> .gitignore
echo ".idea/" >> .gitignore
echo "*.log" >> .gitignore
```

## Override

- Global: `cpm hook --global --disable no-artifacts`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-artifacts = false
  ```

- One commit: `git commit --no-verify`
