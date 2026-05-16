---
summary: cpm resolves config and checks like npx — local first, then global, then defaults.
status: proposed
---

# ADR-010: Resolution Strategy (npx-style)

## Context

cpm needs to know where to find config, checks, and tools. Like npx resolves packages (local node_modules → global → download), cpm should have a clear resolution order.

## Decision

### Resolution order (first found wins)

```text
1. Project local    ./cpm.toml + ./lib/cpm/
2. Global config    ~/.config/cpm/cpm.toml
3. Built-in defaults (embedded in cpm binary/wrapper)
```

### What each level provides

| Level | Config | Checks | Use case |
|-------|--------|--------|----------|
| Project (`./`) | `cpm.toml` | `lib/cpm/checks/` | Per-repo settings, pinned version |
| Global (`~/.config/cpm/`) | `cpm.toml` | `~/.local/share/cpm/checks/` | User defaults, shared across repos |
| Built-in | hardcoded defaults | embedded | Zero-config fallback |

### Config merging (deep merge, local wins)

```text
built-in defaults
  ← merged with ~/.config/cpm/cpm.toml (global)
    ← merged with ./cpm.toml (project, wins)
```

Example: global sets `spinner = "dots"`, project overrides `spinner = "pipe"` → pipe wins.

### `cpm -g` (global scope)

```bash
cpm config set spinner pipe          # writes to ./cpm.toml
cpm config set -g spinner pipe       # writes to ~/.config/cpm/cpm.toml
cpm config get spinner               # shows resolved value + source
```

Output:
```text
spinner = "pipe"  (from: ./cpm.toml)
```

### Make compatibility

```bash
# cpm detects Makefile and delegates when appropriate:
cpm check fast
  → if ./Makefile has 'cpm-fast' target → make cpm-fast
  → else → bash lib/cpm/shell/cpm-check.sh fast

# Or: Makefile delegates to cpm
cpm-fast:
    @cpm check fast
```

Either direction works. The Makefile is a thin alias layer.

### Global cpm.toml (`~/.config/cpm/cpm.toml`)

User-wide defaults (not committed anywhere):

```toml
# ~/.config/cpm/cpm.toml
[ui]
spinner = "arc"
mode = "auto"

[tools]
install-mode = "auto"    # don't ask me, just install

[user]
name = "Remi"
```

### CLI commands for config manipulation

```bash
cpm config list              # show all resolved config
cpm config get <key>         # show value + source
cpm config set <key> <val>   # write to ./cpm.toml
cpm config set -g <key> <val> # write to global
cpm config edit              # open cpm.toml in $EDITOR
cpm config edit -g           # open global config
```

## Consequences

- Zero-config works (built-in defaults)
- Per-project customization via `./cpm.toml`
- User preferences via `~/.config/cpm/cpm.toml`
- `cpm -g` for global manipulation
- Make stays compatible (either direction)
- Resolution is predictable and inspectable (`cpm config get`)

## References

- npx resolution: local node_modules → global → download
- git config: system → global → local (same pattern)
- @see docs/adrs/adr-009-package-distribution.md
- @see install.sh (installs to ~/.local/)
