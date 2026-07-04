# ADR-007: CPM as Engineering Knowledge Base

**Status:** Proposed  
**Date:** 2026-05-11  
**Context:** llama-cli ADR-048 bevat uitgebreide quality framework kennis

## Problem

Engineering best practices zijn verspreid over meerdere repos:

- llama-cli: 118 ADRs, uitgebreid quality framework (ADR-048)
- workspace-tui: ~30 ADRs, proven patterns
- cpm: 6 ADRs, basis documentatie

**Duplication:**

- Concepten worden opnieuw uitgelegd
- Best practices niet herbruikbaar
- Geen centrale knowledge base

## Decision

## CPM wordt de centrale Engineering Knowledge Base

### Structuur

```text
cpm/
├── docs/
│   ├── adr/                    # CPM-specific decisions
│   ├── patterns/               # Reusable patterns
│   │   ├── ui-pattern.md       # Van ADR-004
│   │   ├── registry-pattern.md # Van ADR-005
│   │   └── ...
│   ├── frameworks/             # Complete frameworks
│   │   ├── quality-framework.md    # Van llama-cli ADR-048
│   │   ├── v-model.md
│   │   └── cmmi-levels.md
│   ├── principles/             # Engineering principles
│   │   ├── rtfm.md
│   │   ├── kiss.md
│   │   ├── yagni.md
│   │   └── ...
│   └── guides/                 # How-to guides
│       ├── model-selection.md
│       ├── ai-prompts.md
│       └── ...
└── knowledge/                  # Imported ADRs
    ├── llama-cli/              # 118 ADRs
    ├── workspace-tui/          # 30 ADRs
    └── index.md                # Searchable index
```

### Import Strategy

## Optie 1: Symlink (Aanbevolen)

```bash
cd cpm
ln -s ../llama-cli/docs/adr knowledge/llama-cli
ln -s ../workspace-tui/adr knowledge/workspace-tui
```

**Voordelen:**

- Geen duplicatie
- Updates blijven in originele repo
- Centrale toegang via cpm

## Optie 2: Copy + Reference

```bash
# Kopieer alleen de "universal" ADRs
cp llama-cli/docs/adrs/adr-048-quality-framework.md cpm/docs/frameworks/
# Voeg reference toe aan origineel
```

**Voordelen:**

- CPM is self-contained
- Kan curated versies maken

## Content Organization

### 1. Patterns (Herbruikbaar)

Van workspace-tui en llama-cli:

- Centralized UI pattern
- Check registry pattern
- 3-tier quality gates
- Registry-driven runners
- Autofix phase pattern

### 2. Frameworks (Complete systemen)

Van llama-cli ADR-048:

- Lean Quality Framework (LQF)
- CMMI 0-3 levels
- V-Model integration
- Three Pillars (Operational/Tactical/Strategic)
- Thin-V change process

### 3. Principles (Engineering wisdom)

Van llama-cli:

- RTFM, KISS, YAGNI, NBI, HIPI, C4C, C4I
- Chess principle (every check serves ≥2 purposes)
- Black-box principle
- Golden Thread (Strategic → Tactical → Operational)

### 4. Guides (Practical how-to)

Van llama-cli:

- Model selection guide
- AI prompt templates
- Sprint planning
- RAID management

## Index Generation

```bash
# Auto-generate searchable index
cpm knowledge index

# Output: knowledge/index.md
# - All ADRs by topic
# - All patterns by category
# - All principles with definitions
# - Cross-references
```

## Search

```bash
# Search knowledge base
cpm knowledge search "mutation testing"
# → llama-cli/adr-067-mutation-testing.md
# → frameworks/quality-framework.md (section 3.4)

cpm knowledge search "CMMI"
# → frameworks/quality-framework.md
# → adr-006-quality-framework-vision.md
```

## Benefits

### For CPM Users

- ✅ One place for all engineering knowledge
- ✅ Learn from proven patterns
- ✅ Copy-paste ready examples
- ✅ Understand the "why" behind checks

### For Original Repos

- ✅ ADRs stay in their repo (symlink)
- ✅ No migration needed
- ✅ Increased visibility
- ✅ Cross-pollination of ideas

### For New Projects

- ✅ Bootstrap with best practices
- ✅ Don't reinvent the wheel
- ✅ Learn from 150+ ADRs
- ✅ Gradual adoption (pick what you need)

## Migration Plan

### Phase 1: Symlink Import

```bash
cd cpm
mkdir -p knowledge
ln -s ../llama-cli/docs/adr knowledge/llama-cli
ln -s ../workspace-tui/adr knowledge/workspace-tui
```

### Phase 2: Extract Universal Content

```bash
# Identify "universal" ADRs (not project-specific)
# Copy to cpm/docs/frameworks/ or cpm/docs/patterns/
# Add reference to original
```

### Phase 3: Generate Index

```bash
# Create knowledge/index.md
# Categorize by:
# - Topic (testing, security, architecture)
# - CMMI level
# - Language (C++, TypeScript, universal)
```

### Phase 4: Add Search

```bash
# Implement cpm knowledge search
# Full-text search across all ADRs
```

## Example: Using the Knowledge Base

```bash
# Developer wants to add mutation testing
cpm knowledge search "mutation"
# → llama-cli/adr-067-mutation-testing.md
# → frameworks/quality-framework.md (CMMI 2, check 2.2)

# Read the ADR
cat knowledge/llama-cli/adr-067-mutation-testing.md

# See implementation
cd ../llama-cli
make mutation

# Copy pattern to your project
```

## Maintenance

### Who Updates What?

| Content | Owner | Update Location |
|---------|-------|-----------------|
| Project-specific ADRs | Original repo | llama-cli/docs/adr/ |
| Universal patterns | CPM | cpm/docs/patterns/ |
| Frameworks | CPM (curated) | cpm/docs/frameworks/ |
| Index | Auto-generated | cpm knowledge index |

### Sync Strategy

```bash
# Weekly: regenerate index
cd cpm
cpm knowledge index

# On major changes: update curated content
# Example: llama-cli ADR-048 updated
# → Review changes
# → Update cpm/docs/frameworks/quality-framework.md if needed
```

## Success Metrics

- 150+ ADRs accessible via CPM
- < 10s to find relevant knowledge
- New projects bootstrap with proven patterns
- Zero duplication of universal content

## Open Questions

1. **Ownership:** Who maintains curated content in cpm/docs/?
2. **Versioning:** How to handle breaking changes in patterns?
3. **Contribution:** How do other repos contribute patterns?
4. **Format:** Markdown only, or also code examples?

## References

- llama-cli ADR-048: Quality framework (source material)
- ADR-006: CPM as quality framework
- ADR-004: Centralized UI pattern
- ADR-005: Check registry pattern
