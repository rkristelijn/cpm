# ADR-003: Shared Tooling Strategy

**Status:** Superseded  
**Date:** 2026-05-11  
**Note:** Symlink approach rejected in practice. Consumers vendor cpm via `cp -R`. See install.sh.
**Context:** Multiple repos (workspace-tui, llama-cli, dotfiles) duplicate Makefiles, shell scripts, and ADR patterns

## Problem

Across ~/git/hub repos, significant duplication exists:

### Current State Analysis

**workspace-tui** (TypeScript/Node):

- Makefile: 3-tier quality gates (check-fast/check/check-all), LOG=1 pattern, skip system
- Scripts: 40+ checks (security/quality/code/structure), lib/ utilities (ui.sh, log.sh, skip.sh)
- Features: CMMI maturity scoring, git hooks, AI agent configs

**llama-cli** (C++):

- Makefile: Similar 3-tier gates, LOG=1, extensive targets (100+)
- Scripts: 100+ scripts (lint/test/security/gh/dev), highly organized
- Features: GitHub integration, SAST suite, mutation testing, traceability

**dotfiles**:

- Makefile: Basic install/check, symlink validation, idempotency checks
- Scripts: Minimal (setup scripts only)

**cpm** (C++):

- Makefile: Minimal (build/clean/install/test)
- No scripts directory
- 2 ADRs only

### Duplication Patterns

1. **Makefile boilerplate**: LOG=1 pattern, help target, .PHONY declarations
2. **Quality checks**: gitleaks, shellcheck, parity checks, syntax validation
3. **Git hooks**: pre-commit, pre-push patterns
4. **ADR structure**: Numbering, status, format conventions
5. **Shell utilities**: UI helpers, logging, error handling

### Missing Capabilities

- **cpm**: No quality gates, no scripts infrastructure, minimal CI
- **dotfiles**: No lint/test framework, basic checks only
- **workspace-tui**: Missing GitHub integration, SAST tools
- **All**: No shared library for common patterns

## Decision

**Create `cpm` as the central tooling repository** with reusable components:

```text
cpm/
├── lib/
│   ├── make/
│   │   ├── common.mk      # LOG=1, help, .PHONY patterns
│   │   ├── quality.mk     # 3-tier gates (check-fast/check/check-all)
│   │   ├── format.mk      # Language-agnostic formatters
│   │   └── git.mk         # Hook installation targets
│   ├── shell/
│   │   ├── ui.sh          # Colors, spinners, tables
│   │   ├── log.sh         # Structured logging
│   │   ├── checks.sh      # Common check patterns
│   │   └── git-hooks.sh   # Hook templates
│   └── templates/
│       ├── adr-template.md
│       ├── pre-commit.sh
│       └── Makefile.template
├── checks/
│   ├── universal/         # Language-agnostic
│   │   ├── gitleaks.sh
│   │   ├── shellcheck.sh
│   │   ├── parity.sh
│   │   └── traceability.sh
│   ├── cpp/               # C++ specific
│   │   ├── clang-format.sh
│   │   └── cppcheck.sh
│   └── typescript/        # TypeScript specific
│       └── biome.sh
└── docs/
    └── integration.md     # How to use in other repos
```

### Integration Pattern

Each repo includes cpm as submodule or symlink:

```makefile
# In workspace-tui/Makefile
include ../cpm/lib/make/common.mk
include ../cpm/lib/make/quality.mk

# Override/extend as needed
lint-custom: biome typescript
```

### Scope

**In cpm/lib** (shared):

- Makefile patterns (LOG=1, help, quality gates)
- Shell utilities (ui, logging, error handling)
- Universal checks (gitleaks, shellcheck, traceability)
- Git hook templates
- ADR templates

**In project repos** (local):

- Language-specific checks (TypeScript, C++)
- Build logic (cmake, pnpm)
- Project-specific workflows
- Custom quality rules

## Consequences

### Positive

- **DRY**: Single source of truth for common patterns
- **Consistency**: Same UX across all repos
- **Maintenance**: Fix once, benefit everywhere
- **Onboarding**: New repos get full tooling instantly
- **Evolution**: Improvements propagate automatically

### Negative

- **Coupling**: Changes to cpm affect all repos
- **Versioning**: Need strategy for breaking changes
- **Complexity**: Extra indirection layer
- **Migration**: Effort to refactor existing repos

### Risks

- Over-abstraction (YAGNI)
- Version skew between repos
- Merge conflicts in shared code

## Implementation Plan

1. **Phase 1** (Week 1): Extract to cpm/lib
   - common.mk (LOG=1, help)
   - ui.sh, log.sh
   - gitleaks.sh, shellcheck.sh

2. **Phase 2** (Week 2): Integrate in llama-cli
   - Replace duplicated code
   - Test full quality gate
   - Document integration

3. **Phase 3** (Week 3): Integrate in workspace-tui
   - Adapt TypeScript-specific parts
   - Verify skip system works

4. **Phase 4** (Week 4): Enhance dotfiles
   - Add quality gates
   - Integrate git hooks

## Alternatives Considered

### 1. Keep as-is (rejected)

- Pro: No migration effort
- Con: Duplication continues, maintenance burden grows

### 2. Monorepo (rejected)

- Pro: True code sharing
- Con: Loses per-project autonomy, complex CI

### 3. Package manager (npm/brew) (rejected)

- Pro: Versioning built-in
- Con: Overkill for personal repos, publish overhead

### 4. Git submodules (considered)

- Pro: Version pinning per repo
- Con: Submodule complexity, sync issues

### 5. Symlinks to cpm (chosen)

- Pro: Simple, instant updates
- Con: Requires cpm in fixed location

## Success Metrics

- Lines of duplicated code reduced by 60%
- New repo setup time < 5 minutes
- Quality gate consistency across all repos
- Zero regressions in existing checks

## References

- ADR-001: cpm concept
- ADR-002: Feature parity with make/npm
- llama-cli ADR-048: Quality framework
- workspace-tui: CMMI maturity model
