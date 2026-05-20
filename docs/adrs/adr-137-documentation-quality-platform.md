---
summary: Documentation quality as a 5-layer system — from sentence linting to cognitive load analysis.
status: accepted
---

# ADR-137: Documentation Quality Platform

## Context

cpm now has `doc-style` (writing quality) and `doc-complexity` (structure basics). But documentation quality is much deeper than sentence-level linting. Poor docs are the #1 reason developers abandon tools.

## Decision

Documentation quality is a 5-layer system. We implement bottom-up, each layer building on the previous.

## The 5 Layers

```text
┌─────────────────────────────────────────┐
│ 5. Engineering Quality                  │  ← docs-as-code (snippets compile, links work)
├─────────────────────────────────────────┤
│ 4. Cognitive Load Analysis              │  ← UX for docs (concept density, memory load)
├─────────────────────────────────────────┤
│ 3. Information Architecture             │  ← doc-purpose validation (Diátaxis)
├─────────────────────────────────────────┤
│ 2. Structural Quality                   │  ← scanability, flow, navigation
├─────────────────────────────────────────┤
│ 1. Writing Quality                      │  ← sentence linting (DONE)
└─────────────────────────────────────────┘
```

## Layer 1: Writing Quality (implemented)

Sentence-level linting. Comparable to Vale, Microsoft Style Guide, Google Developer Docs Style Guide.

### Current checks

| Rule | Detects | Autofix |
|------|---------|---------|
| weasel-word | "simply", "just", "obviously" | ✅ Remove word |
| passive-voice | "is created", "will be generated" | ⚠️ Needs context |
| mixed-addressing | you/we/je mixed in one doc | ❌ Author choice |
| non-imperative | "You should run X" | ✅ Strip prefix |
| undefined-acronym | First use without expansion | ❌ Needs full name |
| hedging | "probably", "you might want to" | ✅ Remove/simplify |

### Planned additions

| Rule | Detects | Autofix |
|------|---------|---------|
| repeated-words | "Click the button button" | ✅ Remove duplicate |
| vague-pronouns | "It does this automatically" | ❌ Specify subject |
| weak-verbs | "handles/manages/processes" | ⚠️ Suggest stronger |
| filler-phrases | "please note that" | ✅ Remove |
| unnecessary-future | "will create" | ✅ → "creates" |
| negative-instructions | "Do not forget to…" | ✅ → "Remember to…" |
| hidden-steps | Skipped assumptions | ❌ Add prerequisite |
| ambiguous-reference | "this/that/these" without noun | ❌ Specify noun |

## Layer 2: Structural Quality

Determines if docs are scannable. This is where most docs fail.

### Checks

| Rule | Problem |
|------|---------|
| missing-summary | No TL;DR at top |
| no-prerequisites | User doesn't know dependencies |
| no-outcome | Unknown end result |
| no-next-steps | Dead-end docs |
| missing-example | Theory without example |
| example-before-explanation | Bad learning flow |
| inconsistent-headings | Random heading styles |
| orphan-section | Heading with 1 sentence |
| giant-list | 40 bullets without grouping |
| duplicate-sections | Same explanation repeated |
| broken-flow | Jumps between topics |
| inconsistent-terminology | "workspace/project/app" interchangeably |

### Autofix

| Type | Possible |
|------|----------|
| Auto TOC generation | ✅ |
| Heading normalization | ✅ |
| List flattening | ✅ |
| Table alignment | ✅ |
| Code fence language fix | ✅ |
| Broken heading levels | ✅ |

## Layer 3: Information Architecture

Validate structure per document type (Diátaxis model).

### Document types and required sections

**Tutorial:**
- prerequisites
- expected result
- numbered steps
- verification
- next steps

**ADR:**
- context
- decision
- consequences
- alternatives considered

**API Reference:**
- request format
- response format
- error codes
- examples

**Troubleshooting:**
- symptom
- cause
- solution
- prevention

### Detection

Classify doc type from filename/path/content, then validate required sections exist.

## Layer 4: Cognitive Load Analysis

Treat docs like UX — measure mental effort required.

### Checks

| Rule | Detects |
|------|---------|
| context-switching | Too many topic changes |
| concept-density | Too many new terms per section (max 5) |
| high-abstraction | Abstract without concrete example |
| no-reinforcement | Concept explained but never applied |
| stacked-instructions | 12 steps in 1 paragraph |
| memory-overload | User must remember too much |
| hidden-state | Docs assume implicit knowledge |
| high-scroll-distance | Important info too far away |

### Metrics

```yaml
# Documentation Complexity Budget
maxParagraphLines: 8
maxConceptsPerSection: 3
maxHeadingDepth: 4
maxScrollToExample: 20 lines
maxNewTermsPerSection: 5
requiredExampleRatio: 0.15
```

## Layer 5: Engineering Quality

Docs-as-code — verify docs match reality.

### Checks

| Rule | Detects |
|------|---------|
| stale-code-snippets | Code doesn't compile |
| outdated-cli-output | Terminal output mismatch |
| dead-links | Broken internal/external links |
| missing-version | No version context |
| api-drift | Docs ≠ implementation |
| invalid-json | Broken JSON/YAML snippets |
| inconsistent-formatting | Markdown style chaos |

### Killer feature: `cpm verify docs`

```bash
cpm verify docs    # extracts code blocks, runs them, reports failures
```

## Composite Scores

```text
$ cpm docs score

  Readability:      82
  Structure:        91
  Task Completion:  67
  Maintainability:  88
  Cognitive Load:   54

  Overall: B+ (76/100)
```

### Skimmability score

- Headings per 50 lines
- Code/example ratio
- Average paragraph length
- Visual breaks (images, diagrams, tables)
- List density

### Time to first success

- Scroll distance to first actionable step
- Number of prerequisites
- Number of concepts before first example
- Steps to working result

## Implementation Priority

| Layer | Effort | Impact | Priority |
|-------|--------|--------|----------|
| 1. Writing Quality | Done | Medium | ✅ Shipped |
| 2. Structural Quality | Low | High | Next |
| 3. Information Architecture | Medium | High | After 2 |
| 4. Cognitive Load | Medium | Very High | After 3 |
| 5. Engineering Quality | High | Very High | After 4 |

## Design Constraints

- All checks file-based (no network, no compilation for basic checks)
- Dictionaries external (cSpell-compatible txt files)
- Autofix non-destructive (preview mode by default)
- Scores configurable per project via cpm.toml
- Language-agnostic (works on any markdown)

## References

- @see dictionaries/ (cSpell-compatible word lists)
- @see src/checks/docs/doc_style.cpp (Layer 1 implementation)
- @see src/checks/docs/doc_complexity.cpp (Layer 2 basics)
- @see [Diátaxis](https://diataxis.fr/) (Layer 3 framework)
- @see [Vale](https://vale.sh/) (comparable tool, Ruby-based)
- @see [Google Developer Docs Style Guide](https://developers.google.com/style)
