---
title: "Architecture: decompose cmd_ops.cpp into feature modules + migrate shell checks to rules"
type: feat
created: 2026-08-31
labels: [architecture, refactor, tech-debt]
remote:
---

## What

Two related refactors to clean up cpm's architecture:

### 1. Split god-files into feature modules

Current state: `cmd_ops.cpp` (~27k lines) and `commands.cpp` (~22k lines) contain everything.

Target:

```
src/commands/
  cmd_project.cpp    ← new, init, eject
  cmd_build.cpp      ← build, run, test, coverage, clean
  cmd_config.cpp     ← get, set, bump, version
  cmd_hooks.cpp      ← hook, unhook (per-repo + global)
  cmd_tools.cpp      ← install, uninstall, audit, tools
  cmd_report.cpp     ← score, findings, xref
  cmd_git.cpp        ← commit, issue, todo
  cmd_sort.cpp       ← sort (already separate)
src/lib/              ← shared utilities
  lib_toml.cpp       ← TOML parsing (extract from toml.cpp)
  lib_git.cpp        ← git operations (extract from commands)
  lib_fs.cpp         ← filesystem (extract from io/)
  lib_ui.cpp         ← terminal output (already in ui.cpp)
```

### 2. Migrate 188 shell check scripts to rules

Current state: three check systems that overlap:

| System | Count | What | Speed |
|--------|-------|------|-------|
| Shell scripts (`checks/*.sh`) | 188 | Bash grep/awk | Slow (~50ms startup each) |
| Rules (`rules/*.rule`) | 964 | Declarative patterns | Fast (C++ engine) |
| C++ checks (`src/checks/*.cpp`) | 32 | Compiled in binary | Fastest |

Target:
- **Rules** (declarative) for all pattern-matching checks (~150 of the 188 scripts)
- **C++ checks** for complex analysis (lockfile parsing, AST, import graph, etc.)
- **Shell scripts** only for setup/install/release tooling — NOT for check logic

Migration priority:
1. Shell scripts that are just `grep -rn "pattern"` → rule file (trivial)
2. Shell scripts that combine multiple greps → multi-pattern rule file
3. Shell scripts with complex logic (parsing, API calls) → C++ check or keep as shell

### Which shell scripts to keep

Only `scripts/*.sh` (not `checks/*.sh`):
- `setup-global-hooks.sh` — installs global hooks (bash is fine, runs once)
- `setup-tools.sh` — installs external tools
- `setup-pii-vault.sh` — PII vault setup
- `release.sh` — release automation
- `benchmark.sh` — performance testing
- `generate-*.sh` — doc/code generation

## Why

- 188 shell scripts × ~50ms = 9.4s sequential overhead (just bash startup)
- Rule engine processes 964 rules in ~2s (parallel, C++ native)
- Shell scripts are hard to test, hard to compose, hard to distribute
- `cmd_ops.cpp` is a 27k-line god file — any change risks breaking unrelated features
- No feature isolation — hooks, config, reporting all share one file

## Value

- Quality characteristic: **Maintainability** + **Performance Efficiency**
- Stakeholder benefit: Faster checks, easier to add new checks (just write a .rule file), cleaner codebase for contributors

## Acceptance criteria

- [ ] `cmd_ops.cpp` split into ≤8 files, each <500 lines
- [ ] `commands.cpp` split into ≤4 files, each <500 lines  
- [ ] `src/lib/` contains shared utilities used by multiple command files
- [ ] ≥50 shell check scripts migrated to .rule files
- [ ] No shell scripts remain in `checks/` that are just grep-based pattern matching
- [ ] All existing tests pass after split
- [ ] `cpm check` runtime improves by ≥20% after migration

## Done when

- [ ] Acceptance criteria met
- [ ] No regression (all tests pass)
- [ ] Docs updated (architecture.md reflects new structure)

## References

- Current architecture: `docs/architecture.md`
- Rule file format: `docs/features/rules.md`
- ADR-129: Unified findings contract
- Related TODO item: "Integrate rule-scan into `cpm check`" (Priority 2)
- Related TODO item: "Gen1→Gen2 shell migration" (Priority 2)
