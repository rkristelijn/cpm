# ADR-126: Traceability by Design

*Status*: Draft · *Date*: 2026-05-18

## Context

cpm has 140 ADRs, 6 V-model designs, and growing code. Currently:

- Cross-references exist but are inconsistent
- No systematic way to verify links are valid
- TODO/FIXME comments exist but aren't tracked
- Designs (drawio) aren't linked from ADRs

**Problem**: Without traceability, decisions become disconnected from implementation, leading to:

- "Why was this done?" questions unanswered
- Dead code that can't be traced to a decision
- ADRs that don't reflect actual implementation
- Tests that don't trace to requirements

## Decision

Traceability is **embedded, not delivered**. No separate traceability documents.

### Core Principle

> Every artifact links to its "why" via lightweight, machine-readable references.

### Identifier Schema

| Artifact | Prefix | Example | Location |
|----------|--------|---------|----------|
| **ADR** | `ADR-` | `ADR-126` | docs/adrs/adr-126-*.md |
| **Design** | `DES-` | `DES-VMODEL-1` | docs/designs/*.drawio |
| **Ticket** | `cpm-` | `cpm-42` | TODO.md, GitHub Issues |
| **Check** | `CHK-` | `CHK-XREF` | cpm.toml [checks] |
| **GitHub Issue** | `#` | `#42` | GitHub Issues |
| **GitHub MR** | `!` | `!45` | GitHub Merge Requests |

### Reference Patterns

#### Code → ADR, Design, Ticket (Doxygen/Javadoc style)

```cpp
/**
 * @file parser.cpp
 * @brief Parses cpm.toml configuration
 * @see ADR-126          # Beslissing
 * @see DES-VMODEL-1     # Design
 * @see cpm-42           # Ticket
 * @copyright MIT        # SPDX
 * SPDX-License-Identifier: MIT
 */
void parse_config() {
    // TODO(cpm-42): memory leak - see ADR-047
    // FIXME(cpm-43): handle edge case - closes #43
}
```

#### ADR → Code, Design, GitHub

```markdown
# ADR-126: Traceability by Design

*Implements*: ADR-084
*Related*: DES-VMODEL-1
*Ticket*: cpm-42
*GitHub*: closes #42, related !45

## Decision

...
```

#### Git Commit Messages

```text
feat(parser): add config parsing

Implements: ADR-126
Ticket: cpm-42
Closes: #42
Related: !45
```

### External Integrations

| Source | Pattern | Meaning |
|--------|---------|---------|
| **GitHub Issues** | `closes #N`, `fixes #N` | Resolves issue |
| **GitHub MRs** | `closes !N`, `related !N` | MR reference |
| **SPDX** | `SPDX-License-Identifier: MIT` | License |
| **Doxygen** | `@see ADR-126`, `@sa DES-VMODEL-1` | Cross-ref |

### Automated Validation

```bash
# Regex patterns for validation
@see\s+(ADR-[0-9]+|DES-[A-Z]+-[0-9]+|cpm-[0-9]+)  # Doxygen refs
(closes|fixes|related)\s+(#[0-9]+|![0-9]+)          # GitHub refs
SPDX-License-Identifier:\s+[A-Za-z0-9.-]+           # SPDX
(TODO|FIXME)\(cpm-[0-9]+\)                          # Ticket refs
```

### Traceability Matrix Algorithm

The traceability matrix is **generated, not maintained**. It builds itself from embedded references.

#### Phase 1: Collect References

```bash
# Collect all @see references from code
grep -rhs '@see\s\+\(ADR-[0-9]\+\|DES-[A-Z]\+-[0-9]\+\|cpm-[0-9]\+\)' src/ docs/

# Collect all TODO/FIXME with tickets
grep -rhsE '(TODO|FIXME)\(cpm-[0-9]+\)' src/

# Collect ADR metadata
grep -rhsE '^\*Implements\*:|^\*Related\*:|^\*Ticket\*:' docs/adrs/
```

#### Phase 2: Build Matrix

```text
FILE          ADR-126  DES-VMODEL-1  cpm-42  cpm-43
----------------------------------------------------
src/main.cpp    ✓          -          ✓        -
src/parser.cpp  ✓          ✓          -        ✓
docs/adrs/...   -          -          ✓        -
```

#### Phase 3: Find Coverage Gaps

```bash
# Find files without any @see references
for f in src/*.cpp src/*.h; do
  if ! grep -q '@see' "$f"; then
    echo "NO TRACEABILITY: $f"
  fi
done

# Find ADRs without code references
for adr in docs/adrs/adr-*.md; do
  refs=$(grep -c '@see' "$adr" || echo 0)
  if [ "$refs" -eq 0 ]; then
    echo "UNLINKED ADR: $adr"
  fi
done
```

### Automated Checks

```toml
[checks]
code-adr-links = true      # Every major file has @see to ADR
adr-code-refs = true       # ADRs reference existing files
adr-design-xref = true     # ADRs reference existing drawio files
todo-scraper = true        # Scrape TODO → TECHDEBT.md
xref-validate = true       # All @see links resolve
traceability-coverage = true  # Report files without traceability
```

### Commands

```bash
cpm todo        # Show all TODO/FIXME with ticket refs
cpm xref        # Validate all cross-references
cpm trace       # Generate traceability matrix (DOT/PlantUML)
cpm coverage    # Show traceability coverage per file
```

### Traceability Coverage Report

```bash
$ cpm coverage

Traceability Coverage
=====================

Files with traceability:  15 / 20 (75%)
Files without traceability: 5

Missing coverage:
  src/io/filesystem.cpp  (no @see to ADR)
  src/runner.cpp        (no @see to ADR)
  src/setup.cpp         (no @see to ADR)
  tests/integration.cpp (no @see to ADR)
  lib/shell/commit.sh   (no @see to ADR)

ADRs with code links:    45 / 140 (32%)
ADRs without links:      95

Most linked ADRs:
  ADR-022: 12 files
  ADR-004: 8 files
  ADR-126: 5 files
```

## Consequences

### Positive

- Traceability emerges naturally from development
- No separate document to maintain
- Machine validation catches broken links
- TODO scraping provides tech debt visibility
- Integrates with GitHub Issues/MRs
- SPDX compliance for licensing
- Coverage reports identify gaps automatically

### Negative

- Requires discipline to add `@see` comments
- Initial effort to add links to existing code
- Some manual review still needed
- Coverage starts low, improves over time

## Implementation

1. Add `xref-validate` check (shell script) ✅
2. Add `todo-scraper` check (shell script) ✅
3. Add `cpm todo` command ✅
4. Add `cpm xref` command ✅
5. Add `traceability-coverage` check (shell script) - TODO
6. Add `cpm trace` command (DOT/PlantUML output) - TODO
7. Add reference patterns to ADR template
8. Backfill `@see` comments in existing code (gradual)

## References

- llama-cli ADR-023: Self-Documenting Processes
- llama-cli ADR-047: AI-Guided Development QA
- [V-model designs](../designs/v-model-level-0.6.drawio)
- [SPDX Standard](https://spdx.dev/)
- [Doxygen @see](https://www.doxygen.nl/manual/commands.html#cmdsee)
