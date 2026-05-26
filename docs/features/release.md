# Release Process

## How releases work

Releases are fully automated via GitHub Actions. The workflow is tag-only — it never pushes commits to `main`, respecting branch protection.

### Flow

```text
PRs merged to main → trigger release workflow → tag → build → publish
```

1. **Merge PRs** to `main` as normal (CI must pass, branch protection enforced)
2. **Trigger release**: `gh workflow run release.yml` (or via GitHub Actions UI)
3. **Pipeline determines version** from conventional commits since last tag:
   - `feat:` → minor bump
   - `fix:` → patch bump
   - `BREAKING CHANGE` / `!:` → major bump
4. **Tag created** on current HEAD (no commit to main)
5. **Build** for Linux, macOS (arm64 + amd64), Windows
6. **Publish** GitHub Release with binaries + auto-generated release notes
7. **Homebrew formula** pushed to a branch (manual merge if needed)

### Commands

```bash
# Trigger a release
gh workflow run release.yml

# Check what version would be released
bash scripts/release.sh bump

# View release status
gh run list --workflow=release.yml --limit 3
```

### Version in source code

The version in `src/commands/commands.h` and `cpm.toml` is updated manually or via `cpm bump`:

```bash
cpm bump patch   # 0.4.1 → 0.4.2
cpm bump minor   # 0.4.1 → 0.5.0
cpm bump major   # 0.4.1 → 1.0.0
```

This is decoupled from the release tag — the tag is the source of truth for releases.

### Smoke test

The release build runs `make smoke` on Linux/macOS (skipped on Windows). This verifies:

- Binary shows help
- `cpm scan` works
- `cpm init` works

### Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| "No commits to release" | No new commits since last tag | Merge a PR first |
| "tag already exists" | Previous failed run left a tag | `git push --delete origin vX.Y.Z` |
| Windows build fails | POSIX-only code | Check `src/common/compat.h` |
| Publish skipped | Build failed | Check build logs, fix, re-trigger |
