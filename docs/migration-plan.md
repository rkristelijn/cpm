# CPM Migration Plan — From Ad-Hoc to Universal Quality Framework

## Current State Analysis

### What exists across repos

| Feature | llama-cli | workspace-tui | show-master | cpm |
|---------|-----------|---------------|-------------|-----|
| TUI output lib | ad-hoc echo | `scripts/lib/ui.sh` | none | `lib/shell/ui.sh` |
| Check registry | none (Makefile) | `.config/checks-registry.json` | `cpm.toml` | `cpm.toml` |
| CMMI scoring | manual ADR-048 | `maturity-score.sh` | none | concept only |
| Skip mechanism | `lint-exempt:` comments | `skip.sh` + registry | none | none |
| Autofix | per-script (`make format`) | `autofix` field in registry | none | none |
| Log/audit trail | `.tmp/*.log` | `scripts/lib/log.sh` | none | `lib/shell/log.sh` |
| Git hooks | custom scripts | symlinked | none | `cpm.toml [hooks]` |
| Smart filtering | `git diff` in scripts | none | none | none |
| Research freshness | `check-research-freshness.sh` | none | none | none |
| Slop detection | `check-slop.sh` (25 patterns) | none | none | none |

### CMMI Level Mapping (consolidated from all repos)

#### Level 0 — Training Wheels (formatting + structure)

| Check | Category | Autofix | Source |
|-------|----------|---------|--------|
| code formatting (clang-format/biome/ruff) | format | full | all repos |
| yaml formatting | format | full | llama-cli |
| markdown formatting | format | full | llama-cli |
| script formatting (shfmt) | format | full | llama-cli |
| editorconfig compliance | format | full | workspace-tui |
| filename conventions (kebab-case) | structure | none | both |
| clean root (no junk files) | structure | none | workspace-tui |
| bash -n syntax check | format | none | llama-cli (new) |

#### Level 1 — Managed (security + conventions + basic tests)

| Check | Category | Autofix | Source |
|-------|----------|---------|--------|
| gitleaks (secret scan) | security | none | all repos |
| PII detection | security | partial | llama-cli, workspace-tui |
| dangerous patterns | security | none | workspace-tui |
| commit message conventions | process | none | llama-cli |
| shellcheck (script lint) | code | none | llama-cli (new) |
| type checking (tsc/clang-tidy) | code | none | workspace-tui, llama-cli |
| unit tests pass | test | none | all repos |
| pre-commit hooks installed | process | full | all repos |

#### Level 2 — Defined (architecture + complexity + coverage)

| Check | Category | Autofix | Source |
|-------|----------|---------|--------|
| file size limits | structure | none | llama-cli, workspace-tui |
| cyclomatic complexity | code | none | llama-cli, workspace-tui |
| comment ratio (min 20%) | code | none | llama-cli |
| dependency management | structure | none | workspace-tui |
| interface segregation | structure | none | workspace-tui |
| test coverage (>60%) | test | none | workspace-tui |
| e2e tests pass | test | none | llama-cli |
| ADR exists for decisions | process | none | llama-cli |
| import path conventions | code | partial | workspace-tui |
| portability checks | code | none | llama-cli (new) |

#### Level 3 — Quantitative (metrics + detection + research)

| Check | Category | Autofix | Source |
|-------|----------|---------|--------|
| slop detection (code) | quality | none | llama-cli (new) |
| slop detection (docs) | quality | none | llama-cli (new) |
| research freshness | process | none | llama-cli (new) |
| traceability (ADR→code→test) | quality | none | llama-cli, workspace-tui |
| duplication detection | code | none | llama-cli, workspace-tui |
| dead code detection | code | none | llama-cli |
| consistency checks | code | none | llama-cli |
| feature coverage markers | test | none | llama-cli |
| mutation testing | test | none | llama-cli |
| log/audit trail | process | full | workspace-tui, cpm |

#### Level 4 — Optimizing (trends + auto-remediation)

| Check | Category | Autofix | Source |
|-------|----------|---------|--------|
| CI cache optimization | infra | full | llama-cli (ADR-122) |
| trend analysis (score over time) | metrics | none | workspace-tui (log.sh) |
| auto-fix loop (format→lint→retry) | process | full | llama-cli (check-fast) |
| AI-assisted review integration | quality | none | llama-cli (CodeRabbit) |
| summary staleness detection | docs | partial | llama-cli (new) |

---

## Migration Plan

### Phase 0: Boilerplate (PR 1)

**Goal**: CPM can be installed in any repo and does nothing yet except show status.

1. Rewrite `cpm` CLI as a bash script (not C++ — it must work without compilation)
2. `cpm init --lang=<cpp|typescript|python> --level=<0-4>` generates `cpm.toml`
3. `cpm status` reads `cpm.toml` + `checks-registry.json` and shows score
4. `cpm check` is a no-op that prints "no checks configured"
5. Ship `lib/shell/ui.sh`, `lib/shell/log.sh`, `lib/shell/table.sh`
6. Ship `lib/make/common.mk` (log_footer, help target pattern)

**Deliverable**: `setup-cpm.sh` that clones/vendors cpm into `.cpm/` in any repo.

### Phase 1: First Check (PR 2)

**Goal**: One real check runs from cpm, proving the integration model.

1. Pick the simplest universal check: **bash -n syntax validation**
2. Create `checks/universal/syntax-bash.sh` in cpm
3. `cpm check` runs it if `lang` includes shell scripts
4. llama-cli sources `.cpm/checks/universal/syntax-bash.sh` instead of inline code
5. Verify: same output, same behavior, no regression

**Comparison checklist**:

- [ ] Same files scanned
- [ ] Same error messages
- [ ] Same exit codes
- [ ] Same skip/exempt behavior
- [ ] Same performance

### Phase 2: Iterative Migration (PR 3-10)

**Goal**: Move one check per PR, with comparison each time.

Order (easiest/most universal first):

1. `format-scripts` (shfmt) — level 0, autofix=full
2. `sast-secret` (gitleaks) — level 1, autofix=none
3. `check-portability` (shell part) — level 2, autofix=none
4. `check-research-freshness` — level 3, autofix=none
5. `check-slop` (markdown patterns) — level 3, autofix=none
6. `check-scripts` (shellcheck+extra rules) — level 1, autofix=none
7. `check-file-size` — level 2, autofix=none
8. `check-consistency` — level 2, autofix=none

Each PR:

- Moves the check to `cpm/checks/<category>/<name>.sh`
- Updates `checks-registry.json` with metadata (cmmi, autofix, filetypes, tier)
- llama-cli's Makefile calls cpm version instead of local version
- Comparison table in PR description showing before/after

### Phase 3: Scoring + Gamification (PR 11)

**Goal**: `cpm status` shows a real score and level.

1. Port `maturity-score.sh` from workspace-tui to cpm
2. Add `cpm level up` that shows what's needed for next level
3. Add severity levels: info (non-blocking), warning (visible), error (blocks commit)
4. Integrate with `lib/shell/log.sh` for trend tracking

### Phase 4: Self-Healing (PR 12)

**Goal**: Checks that can fix themselves do so automatically.

1. Each check declares `autofix: full|partial|none` in registry
2. `cpm fix` runs all autofix-capable checks in fix mode
3. `cpm check --fix` is alias for fix + check
4. Pre-commit hook runs `cpm fix` silently on staged files

### Phase 5: Multi-Repo Rollout (PR 13-15)

**Goal**: workspace-tui and show-master use cpm.

1. `cpm init` in workspace-tui — migrate from local scripts/lib/ to .cpm/
2. `cpm init` in show-master — already has cpm.toml, wire up checks
3. Verify all three repos share the same check implementations

---

## Architecture

```text
cpm/                          ← the framework repo
├── cpm                       ← main CLI script (bash)
├── lib/
│   ├── shell/ui.sh           ← TUI output (colors, progress, tables)
│   ├── shell/log.sh          ← audit trail
│   ├── shell/skip.sh         ← skip/exempt logic
│   └── make/common.mk        ← shared Makefile patterns
├── checks/
│   ├── universal/            ← any language
│   │   ├── syntax-bash.sh
│   │   ├── research-freshness.sh
│   │   ├── slop-docs.sh
│   │   └── portability-shell.sh
│   ├── security/
│   │   ├── gitleaks.sh
│   │   └── pii.sh
│   └── process/
│       ├── commit-msg.sh
│       └── hooks.sh
├── plugins/
│   ├── cpp/                  ← C++ specific
│   │   ├── format.sh
│   │   ├── lint-tidy.sh
│   │   ├── complexity.sh
│   │   └── slop-code.sh
│   ├── typescript/           ← TS specific
│   │   ├── biome.sh
│   │   └── tsc.sh
│   └── python/
│       └── ruff.sh
└── templates/
    ├── cpm.toml.tmpl
    └── checks-registry.json.tmpl
```

Consumer repo:

```text
my-repo/
├── cpm.toml                  ← project config
├── .cpm/                     ← vendored or symlinked cpm
└── .config/checks-registry.json  ← check metadata + skip config
```

---

## Key Design Decisions

1. **Bash CLI, not compiled** — cpm must work without build tools
2. **Vendor or symlink** — repos can pin a version or track latest
3. **checks-registry.json is the source of truth** — not Makefile, not cpm.toml
4. **Severity: info/warning/error** — only errors block, warnings are visible, info is logged
5. **Smart by default** — checks only run on changed files unless `--full`
6. **Self-healing first** — if a check can fix, it should fix before reporting
7. **No network required** — all checks work offline (no SonarCloud dependency)
8. **Comparison on every migration** — no silent regressions

---

## Milestones

| # | Milestone | PRs | Estimated |
|---|-----------|-----|-----------|
| M1 | CPM boots and shows status | 1 | 1 day |
| M2 | First check runs from cpm | 1 | 1 day |
| M3 | 8 checks migrated | 8 | 3-4 days |
| M4 | Scoring + gamification works | 1 | 1 day |
| M5 | Self-healing/autofix | 1 | 1 day |
| M6 | Multi-repo rollout | 3 | 2 days |

Total: ~10 days for full migration, quality over speed.
