---
summary: Support three repo topologies — solorepo (default), monorepo (nested cpm.toml), polyrepo (cross-repo orchestration with fast search).
status: proposed
---

# ADR-011: Repo Topology — Solo, Mono, Poly

## Context

Projects come in three shapes. CPM must work in all of them without forcing a specific git strategy.

| Topology | Structure | Example |
|----------|-----------|---------|
| Solorepo | 1 repo, 1 cpm.toml | `cpm`, `show-master` |
| Monorepo | 1 repo, N cpm.tomls | `google/`, `nx workspace` |
| Polyrepo | N repos, coordinated | `frontend` + `bff` + `backend` + `db` |

## Decision

### Solorepo (default, no config needed)

Current behavior. `cpm` finds the nearest `cpm.toml` by walking up from `$PWD`.

```bash
cd ~/project/src/deep/path
cpm check    # finds ~/project/cpm.toml automatically
```

### Monorepo (workspace members)

Root `cpm.toml` declares members:

```toml
[workspace]
members = ["packages/*", "services/api"]
```

Each member has its own `cpm.toml` with independent `lang`, `level`, checks.

```bash
cpm check              # current package only (nearest cpm.toml)
cpm check --all        # all workspace members
cpm status             # aggregate score across workspace
cpm status --each      # per-member breakdown
```

Root inherits shared config (tools, hooks) to members unless overridden.

### Polyrepo (cross-repo coordination)

A `cpm-workspace.toml` in a parent directory links independent repos:

```toml
[polyrepo]
members = [
  { path = "../frontend", role = "ui" },
  { path = "../bff", role = "api-gateway" },
  { path = "../backend", role = "service" },
  { path = "../db", role = "persistence" },
]

[polyrepo.search]
engine = "lcode"    # fast cross-repo indexed search
index-path = ".cpm/index"
```

```bash
cpm check --all        # runs cpm check in each member repo
cpm search "AuthToken" # cross-repo search (lcode-style, indexed)
cpm status             # aggregate health across all repos
cpm graph              # dependency graph between repos (future)
```

#### Cross-repo search (lcode-style)

Fast indexed search across all polyrepo members:

```bash
cpm search "handleAuth"          # find across all repos
cpm search "TODO" --role=backend # scoped to role
cpm search --reindex             # rebuild index
```

Implementation: trigram index stored in `.cpm/index/`, rebuilt on `cpm search --reindex` or pre-commit hook. No external service needed — pure local, like `ripgrep` but pre-indexed across repos.

## Implementation

### Phase 1: Walk-up (solorepo improvement)

Find nearest `cpm.toml` by traversing parent directories. Stop at filesystem root or `.git` boundary.

```c
static const char *find_cpm_toml() {
    char dir[PATH_MAX];
    getcwd(dir, sizeof(dir));
    while (strlen(dir) > 1) {
        char path[PATH_MAX];
        snprintf(path, sizeof(path), "%s/cpm.toml", dir);
        if (access(path, F_OK) == 0) return strdup(path);
        char *slash = strrchr(dir, '/');
        if (!slash) break;
        *slash = '\0';
    }
    return NULL;
}
```

### Phase 2: Workspace members (monorepo)

Parse `[workspace]` section, glob-expand members, iterate.

### Phase 3: Polyrepo + search

Parse `cpm-workspace.toml`, build trigram index, provide `cpm search`.

## Consequences

- Solorepo: zero config change, just smarter cpm.toml discovery
- Monorepo: one `[workspace]` section enables multi-package support
- Polyrepo: separate `cpm-workspace.toml` keeps individual repos independent
- Search index is local-only, no network, no external service
- Each topology is opt-in — complexity only appears when you need it

## Acceptance Criteria

- [ ] `cpm check` works from any subdirectory (walk-up)
- [ ] `[workspace]` members discovered and checked with `--all`
- [ ] `cpm-workspace.toml` links multiple repos
- [ ] `cpm search` returns results across polyrepo members in <100ms
- [ ] `cpm status` shows aggregate score for all topologies

## References

- @see adr-008-rebrand-compliance-process-management.md (scope)
- @see adr-010-self-management.md (dogfooding)
- npm workspaces, cargo workspaces, go work (prior art)
- lcode / ripgrep / zoekt (search prior art)
