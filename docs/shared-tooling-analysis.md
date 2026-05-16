# Shared Tooling Analysis

**Date:** 2026-05-11  
**Repos analyzed:** workspace-tui, llama-cli, cpm, dotfiles

## Executive Summary

Significant duplication exists across repos in Makefiles, shell scripts, and quality checks. **Recommendation: Use `cpm` as central tooling library** with symlinks/includes from other repos.

## Detailed Findings

### 1. Makefile Patterns

**Common across all repos:**

```makefile
# LOG=1 pattern for automatic logging
LOG ?= 1
ifdef LOG
  # ... tee to .tmp/<target>.log
endif

# Help target with awk parsing
help: ## Show this help
  @awk 'BEGIN {FS = ":.*##" ...

# .PHONY declarations
.PHONY: help install test ...
```

**Unique to llama-cli/workspace-tui:**

- 3-tier quality gates (check-fast/check/check-all)
- Skip system for temporarily disabling checks
- CMMI maturity scoring

**Missing in cpm/dotfiles:**

- Quality gate framework
- Structured logging
- Skip/unskip mechanism

### 2. Shell Scripts Organization

**workspace-tui** (40 scripts):

```text
scripts/
├── lib/           # ui.sh, log.sh, skip.sh, search.sh, table.sh
├── checks/
│   ├── security/  # gitleaks, pii, dangerous-patterns
│   ├── quality/   # coverage, traceability, docs
│   ├── code/      # complexity, comments, duplication
│   ├── structure/ # filesize, deps, interface-segregation
│   └── format/    # editorconfig, biome
└── git/           # pre-commit, pre-push
```

**llama-cli** (100+ scripts):

```text
scripts/
├── lint/          # 40+ checks (theme, unicode, pii, casts, etc)
├── test/          # unit, e2e, coverage, mutation, bench
├── security/      # SAST suite (semgrep, gitleaks, trivy, etc)
├── gh/            # GitHub integration (PR status, issues, CI)
├── dev/           # setup, bump, todo, log-analysis
├── fmt/           # format-code, format-md, format-yaml
├── ci/            # traceability, install-deps
└── git/           # hooks
```

**dotfiles** (minimal):

```text
scripts/
├── setup-github-ssh.sh
├── ollama-serve.sh
└── ssh-scan.sh
```

**cpm** (none):

- No scripts directory

### 3. Duplication Matrix

| Feature | workspace-tui | llama-cli | cpm | dotfiles |
|---------|--------------|-----------|-----|----------|
| LOG=1 pattern | ✓ | ✓ | ✗ | ✗ |
| Help target | ✓ | ✓ | ✓ | ✓ |
| Quality gates | ✓ | ✓ | ✗ | ✗ |
| ui.sh | ✓ | ✗ | ✗ | ✗ |
| log.sh | ✓ | ✗ | ✗ | ✗ |
| gitleaks | ✓ | ✓ | ✗ | ✓ |
| shellcheck | ✗ | ✓ | ✗ | ✓ |
| Git hooks | ✓ | ✓ | ✗ | ✗ |
| Parity check | ✗ | ✗ | ✗ | ✓ |
| Skip system | ✓ | ✗ | ✗ | ✗ |
| SAST suite | ✗ | ✓ | ✗ | ✗ |
| GitHub tools | ✗ | ✓ | ✗ | ✗ |

### 4. ADR Patterns

**llama-cli**: 118 ADRs (highly mature)

- Consistent numbering (adr-001 to adr-118)
- Status tracking (Proposed/Accepted/Superseded)
- Cross-references (ADR-022: xref-integrity)
- Traceability checks (ADR-095)

**workspace-tui**: ~30 ADRs

- Similar structure
- Less mature

**cpm**: 2 ADRs

- Just started

**dotfiles**: ADR directory exists but empty

### 5. Quality Check Overlap

**Both workspace-tui and llama-cli have:**

- Complexity checks (cyclomatic complexity)
- Comment ratio enforcement
- File size limits
- Duplication detection
- PII detection
- Unicode checks
- Traceability (ADR references in code)

**Only llama-cli has:**

- C++ specific (clang-tidy, cppcheck, casts, conversions)
- SAST suite (semgrep, trivy, grype, osv, checkov)
- Mutation testing
- GitHub integration
- CMMI audit
- Code smells detection
- Inclusivity checks

**Only workspace-tui has:**

- TypeScript specific (biome, typescript compiler)
- Skip system with expiry dates
- Search pattern enforcement
- Emoji usage checks
- Color theme validation

### 6. Missing Capabilities by Repo

**cpm:**

- No quality framework
- No scripts infrastructure
- No git hooks
- No CI/CD patterns
- Minimal testing

**dotfiles:**

- No lint framework
- No test framework
- Basic checks only (syntax, parity)
- No quality gates
- No skip system

**workspace-tui:**

- No SAST tools
- No GitHub integration
- No mutation testing
- Limited security checks

**llama-cli:**

- No skip system (checks always run)
- No centralized UI library

## Recommendations

### 1. Create cpm/lib Structure (Priority: HIGH)

```text
cpm/lib/
├── make/
│   ├── common.mk       # LOG=1, help, .PHONY
│   ├── quality.mk      # 3-tier gates
│   ├── format.mk       # Universal formatters
│   └── git.mk          # Hook targets
├── shell/
│   ├── ui.sh           # From workspace-tui
│   ├── log.sh          # From workspace-tui
│   ├── checks.sh       # Common patterns
│   └── git-hooks.sh    # Hook templates
└── templates/
    ├── adr-template.md
    ├── pre-commit.sh
    └── Makefile.template
```

### 2. Extract Universal Checks (Priority: HIGH)

Move to cpm/checks/universal/:

- gitleaks.sh (security)
- shellcheck.sh (code quality)
- parity.sh (install/uninstall balance)
- traceability.sh (ADR references)
- syntax-check.sh (bash -n, zsh -n)

### 3. Keep Language-Specific in Repos (Priority: MEDIUM)

**llama-cli keeps:**

- C++ checks (clang-tidy, cppcheck, casts)
- SAST suite (semgrep, trivy, etc)
- GitHub tools (PR status, CI analysis)

**workspace-tui keeps:**

- TypeScript checks (biome, tsc)
- Skip system (project-specific)
- Theme validation (project-specific)

### 4. Integration Pattern (Priority: HIGH)

Each repo includes cpm:

```makefile
# Option A: Symlink
include ../cpm/lib/make/common.mk

# Option B: Submodule
include cpm/lib/make/common.mk
```

### 5. Migration Order (Priority: MEDIUM)

1. **Week 1**: Extract to cpm/lib
   - common.mk, ui.sh, log.sh
   - gitleaks, shellcheck
   - Test in isolation

2. **Week 2**: Integrate llama-cli
   - Replace duplicated code
   - Verify all checks pass
   - Document integration

3. **Week 3**: Integrate workspace-tui
   - Adapt TypeScript parts
   - Keep skip system local

4. **Week 4**: Enhance cpm & dotfiles
   - Add quality gates to both
   - Full test coverage

## Optimization Opportunities

### 1. Consolidate UI Libraries

- workspace-tui has mature ui.sh (colors, spinners, tables)
- llama-cli has inline ANSI codes
- **Action**: Move ui.sh to cpm/lib/shell/, use everywhere

### 2. Unify Logging

- workspace-tui has log.sh (structured logging)
- llama-cli has inline logging
- **Action**: Standardize on log.sh pattern

### 3. Standardize Quality Gates

- Both have 3-tier concept but different names
- **Action**: Define in cpm/lib/make/quality.mk

### 4. Share Git Hooks

- Similar pre-commit/pre-push logic
- **Action**: Template in cpm/lib/templates/

### 5. ADR Tooling

- Manual numbering error-prone
- **Action**: Create adr-new.sh script in cpm

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Over-abstraction | Medium | Start minimal, add as needed |
| Version skew | High | Use symlinks (instant sync) |
| Breaking changes | High | Semantic versioning, changelog |
| Merge conflicts | Medium | Clear ownership boundaries |
| Coupling | Medium | Keep language-specific local |

## Success Metrics

- **Code reduction**: 60% less duplication
- **Setup time**: New repo < 5 min
- **Consistency**: Same UX across repos
- **Maintenance**: Fix once, benefit everywhere
- **Quality**: No regressions in checks

## Next Steps

1. Review ADR-003 with team
2. Create cpm/lib structure
3. Extract common.mk + ui.sh
4. Test in llama-cli
5. Document integration pattern
6. Roll out to other repos

## References

- ADR-003: Shared tooling strategy
- llama-cli ADR-048: Quality framework
- workspace-tui: CMMI maturity model
