# hook-no-binaries

## What it catches

Binary files staged for commit: `.exe`, `.dll`, `.so`, `.dylib`, `.class`, `.jar`, `.zip`, `.docx`, `.xlsx`.

## Why it matters

Binary files can't be diffed, bloat the repository, and slow down clones for every developer. They should be managed with Git LFS, artifact registries, or package managers. Accidentally committed binaries remain in git history even after deletion.

## Examples

```text
# Bad
git add app.exe
git add lib/native.dll
git add report.xlsx

# Good
git lfs track "*.exe"
echo "*.dll" >> .gitignore
# Store xlsx in SharePoint/Google Drive, not git
```

## Override

- Global: `cpm hook --global --disable no-binaries`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-binaries = false
  ```

- One commit: `git commit --no-verify`
