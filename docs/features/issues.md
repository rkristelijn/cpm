# cpm issue

Local-first issue tracking. Capture ideas instantly, sync to GitHub when ready.

## Usage

```bash
cpm issue "add TOML array support"   # create issue
cpm issue                            # list open issues
cpm issue show <slug>                # show details
cpm issue close <slug>               # move to closed
cpm issue push                       # push local issues to remote
cpm issue pull                       # pull remote issues to local
cpm issue branch <slug>              # create branch from issue
```

## Workflow

```text
Thought → cpm issue "title" → local file → cpm issue push → GitHub #42
                                                          → cpm issue branch → feat/42-slug
                                                                            → cpm commit → closes #42
```

## Quick capture

```bash
$ cpm issue "fix scan timeout on large repos"
  Created: docs/issues/open/fix-scan-timeout-on-large-repos.md
  Edit to add description and acceptance criteria.
```

## List issues

```bash
$ cpm issue
  #42   Add TOML array support
  #43   Fix scan timeout on large repos
  local Improve error messages
```

Issues without a remote number show `local` — they haven't been synced yet.

## Push to GitHub

```bash
$ cpm issue push
  [push] Pushing local issues...
  [push] #44 ← Improve error messages
  [push] Done.
```

Creates GitHub issues for any local issue without a remote number.

## Pull from GitHub

```bash
$ cpm issue pull
  [pull] Pulling remote issues...
  [pull] #45 → add-ci-pipeline.md
  [pull] #43 closed → fix-scan-timeout-on-large-repos.md
  [pull] Done.
```

Downloads new remote issues and moves remotely-closed issues to `closed/`.

Requires `gh` CLI (`brew install gh`).

## Create branch from issue

```bash
$ cpm issue branch fix-scan-timeout-on-large-repos
  Branch: fix/43-fix-scan-timeout-on-large-repos
```

Branch naming: `type/<remote#>-<slug>` (or `type/<slug>` before sync).

## File format

Issues are plain markdown in `docs/issues/open/`:

```markdown
---
title: Fix scan timeout on large repos
created: 2026-05-18T13:20:00+00:00
labels: [fix, performance]
remote: 43
remote-url: https://github.com/rkristelijn/cpm/issues/43
---

Scan takes >5s on repos with 1000+ files.

## Acceptance

- [ ] Scan completes in <1s for 1000 files
- [ ] Progress indicator shown
```

## Configuration

```toml
# cpm.toml
[issues]
provider = "github"        # github | gitlab | jira | local
repo = "rkristelijn/cpm"
dir = "docs/issues"
```

## Provider pattern

| Provider | CLI needed | Status |
|----------|-----------|--------|
| `local` | none | ✅ works offline, no sync |
| `github` | `gh` | ✅ implemented |
| `gitlab` | `glab` | planned |
| `jira` | `jira` | planned |

## Design decisions

- **No local numbering**: slug is the ID, remote gives the number
- **Committed to git**: issues are documentation, traceable via git blame
- **Closed issues archived**: moved to `docs/issues/closed/`

## Related

- [commit.md](commit.md) — links issues in commit messages
- [hooks.md](hooks.md) — conventional commit validation
