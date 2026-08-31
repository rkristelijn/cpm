# hook-no-large-files

## What it catches

Files larger than 5MB being staged for commit.

## Why it matters

Large files bloat the git repository permanently — even if deleted later, they remain in history. This slows down clones, increases CI times, and wastes storage. Binary assets, database dumps, and log files should use Git LFS or be excluded via .gitignore.

## Examples

```text
# Bad
git add database-dump.sql    # 50MB
git add video-demo.mp4       # 200MB

# Good
git lfs track "*.sql"
echo "*.mp4" >> .gitignore
```

## Override

- Global: `cpm hook --global --disable no-large-files`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-large-files = false
  ```

- One commit: `git commit --no-verify`
