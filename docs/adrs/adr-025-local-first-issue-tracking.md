---
summary: Local-first issue tracking with provider-based sync to GitHub/GitLab/Jira.
status: accepted
---

# ADR-025: Local-First Issue Tracking

## Context

Developers need to capture ideas quickly — from a fleeting thought to a concrete task. Current workflow forces a context switch: open browser, navigate to GitHub Issues, fill in form, come back. This breaks flow.

cpm already orchestrates git workflow (commit, hooks, checks). Issue tracking is the missing piece that connects *what to do* with *how it's done* (branch, commits, closes).

## Decision

Implement `cpm issue` as a local-first issue tracker with optional sync to remote providers.

### Design principles

1. **Local-first**: works offline, no account needed, instant
2. **Plain markdown**: human-readable, diffable, greppable
3. **No local numbering**: filename is the slug, remote gives the number
4. **Provider pattern**: swap GitHub for GitLab/Jira without changing workflow
5. **Committed to git**: issues are documentation, part of the repo history

### File structure

```text
docs/issues/
├── open/
│   ├── add-toml-array-support.md
│   └── fix-scan-timeout.md
└── closed/
    └── setup-ci-pipeline.md
```

### Issue format

```markdown
---
title: Add TOML array support
created: 2026-05-18T13:20:00+02:00
labels: [feat, parser]
remote: 42                          ← filled after sync
remote-url: https://github.com/rkristelijn/cpm/issues/42
---

TOML arrays worden niet geparsed. Nodig voor [checks] sectie.

## Acceptance

- [ ] `[tools]` sectie parsed arrays
- [ ] Tests toegevoegd
```

### Commands

```bash
cpm issue "title"              # create issue (quick, one-liner)
cpm issue                      # list open issues
cpm issue show <slug>          # show issue details
cpm issue close <slug>         # move to closed/
cpm issue sync                 # push/pull to remote provider
cpm issue branch <slug>        # create branch: feat/<remote#>-<slug>
```

### Workflow

```text
1. Capture:   cpm issue "add TOML array support"
              → docs/issues/open/add-toml-array-support.md

2. Sync:      cpm issue sync
              → gh issue create --title "..." --body "..."
              → remote: 42 written to frontmatter

3. Branch:    cpm issue branch add-toml-array-support
              → git checkout -b feat/42-add-toml-array-support

4. Work:      cpm commit
              → shows linked issue, suggests "closes #42"

5. Close:     merge PR with "closes #42"
              → cpm issue sync detects closed → moves to closed/
```

### Provider pattern

```toml
# cpm.toml
[issues]
provider = "github"              # github | gitlab | jira | local
repo = "rkristelijn/cpm"        # remote repo identifier
dir = "docs/issues"             # local storage
```

Provider interface (shell functions):

```bash
issue_sync_push()    # local → remote (create/update)
issue_sync_pull()    # remote → local (download new/closed)
```

Providers are shell scripts in `lib/shell/providers/`:

```text
lib/shell/providers/
├── github.sh      ← uses gh CLI
├── gitlab.sh      ← uses glab CLI
├── jira.sh        ← uses jira CLI (future)
└── local.sh       ← no-op (offline only)
```

### ID strategy

- **No local numbers**. The slug (filename without extension) is the identifier.
- **Remote number** comes from the provider after sync.
- **Branch naming**: `type/<remote#>-<slug>` (after sync) or `type/<slug>` (before sync).
- **Commit linking**: `closes #<remote#>` (conventional commits already support this).

### What gets committed

- `docs/issues/open/*.md` — yes, committed (they're documentation)
- `docs/issues/closed/*.md` — yes, but can be pruned periodically
- Issues are part of the repo: traceable, blameable, searchable

### Integration with cpm commit

When running `cpm commit`, if on a branch that matches an issue:

- Auto-suggest the issue in the commit scope
- Offer to add `closes #N` for the final commit

## Consequences

### Positive

- Zero context switch: create issues from terminal
- Works offline
- Full traceability: issue → branch → commits → close
- No vendor lock-in: switch providers, keep your issues
- Searchable with grep/ripgrep

### Negative

- Merge conflicts possible on issue files (rare, frontmatter only)
- Requires `gh` CLI for GitHub sync (graceful skip if missing)

## Alternatives considered

### git-bug (store in git objects)

Rejected: too complex, not human-readable, requires special tooling to view.

### Sequential numbering

Rejected: causes conflicts in distributed/multi-developer scenarios.

### Don't commit issues

Rejected: loses traceability and offline access.

## References

- @see docs/adrs/adr-014-findings-database.md (JSONL for findings, markdown for issues)
- @see docs/adrs/adr-020-product-vision.md (product vision)
- @see <https://github.com/git-bug/git-bug> (prior art)
