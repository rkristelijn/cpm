# ADR-006: CPM as Quality-Assured Development Framework

**Status:** Proposed  
**Date:** 2026-05-11  
**Supersedes:** ADR-001 (C-only focus)  
**Context:** CPM evolves from C project manager to universal quality framework

## Vision

**CPM = Quality-Assured Development Framework met gamification**

Niet alleen een tool, maar een **filosofie**: software development als een game waar je levels unlockt door quality gates te implementeren.

## Core Concept

### Training Wheels → CMMI Levels

```text
Level 0: Total Anarchy
  ↓ No checks, no structure, prototype mode

Level 0.3: Training Wheels (3 steps)
  ↓ 1. Document reason for change (ADR/commit message)
  ↓ 2. Build acceptance criteria (left side V-model)
  ↓ 3. Automated check (right side V-model)

Level 1: Managed
  ↓ Security basics (gitleaks, secrets)
  ↓ Type safety
  ↓ Basic tests

Level 2: Defined
  ↓ Architecture checks
  ↓ Complexity limits
  ↓ Code coverage

Level 3: Quantitatively Managed
  ↓ Metrics tracking
  ↓ Performance benchmarks
  ↓ Quality trends

Level 4: Optimizing
  ↓ Mutation testing
  ↓ AI-assisted reviews
  ↓ Continuous improvement

Level 5: Excellence
  ↓ Industry best practices
  ↓ Zero defects
  ↓ Full automation
```

### V-Model Integration

Bij elk level voeg je **links** (requirements) en **rechts** (verification) toe:

```text
Level 0.3 (Training Wheels):
  LEFT:  Write ADR with acceptance criteria
  RIGHT: Check ADR exists + criteria met

Level 1 (Managed):
  LEFT:  Define security requirements
  RIGHT: Gitleaks + secret scanning

Level 2 (Defined):
  LEFT:  Architecture decisions
  RIGHT: Complexity checks + structure validation

Level 3 (Quantitatively Managed):
  LEFT:  Quality metrics defined
  RIGHT: Coverage tracking + trend analysis
```

## Language Agnostic

CPM werkt met **elke taal**:

```text
cpm/
├── core/              # Universal patterns (C++ binary)
│   ├── registry       # Check registry engine
│   ├── runner         # Check execution
│   └── scorer         # CMMI scoring
├── adapters/
│   ├── cpp/           # C++ specific checks
│   ├── typescript/    # TypeScript specific
│   ├── python/        # Python specific (community)
│   ├── go/            # Go specific (community)
│   └── rust/          # Rust specific (community)
└── lib/
    ├── make/          # Makefile includes
    └── shell/         # Shell utilities
```

## Lifecycle Modes

CPM past zich aan aan je project fase:

### 1. Prototype Mode (Level 0)

```bash
cpm init --mode=prototype
# Minimal checks: syntax only
# Fast iteration
```

### 2. MVP Mode (Level 0.3 - Training Wheels)

```bash
cpm level up
# Adds: ADR requirement, basic tests, commit message format
```

### 3. Production Mode (Level 1-2)

```bash
cpm level up
# Adds: Security scans, coverage, complexity checks
```

### 4. Maintenance Mode (Level 3)

```bash
cpm mode maintenance
# Adds: Dependency updates, security advisories, deprecation warnings
```

### 5. Disaster Recovery Mode (Level 4)

```bash
cpm mode dr
# Adds: Backup verification, restore tests, failover checks
```

### 6. SLA Mode (Level 5)

```bash
cpm mode sla
# Adds: Performance monitoring, uptime checks, SLO validation
```

## Implementation Strategy

### Phase 1: Core (C++)

```cpp
// cpm core binary
class CheckRegistry {
  void load(const std::string& path);
  std::vector<Check> getChecksForTier(Tier tier);
  bool isSkipped(const std::string& check);
};

class CheckRunner {
  Result run(const Check& check);
  void printProgress(int current, int total);
};

class CMMIScorer {
  int calculateScore(const CheckRegistry& registry);
  Level getCurrentLevel();
  std::vector<Check> getNextLevelRequirements();
};
```

### Phase 2: Adapters (Plugins)

```toml
# cpm.toml
[project]
language = "typescript"
level = 1

[adapters.typescript]
checks = ["biome", "tsc", "eslint"]
format = ["biome --write"]

[adapters.cpp]
checks = ["clang-tidy", "cppcheck"]
format = ["clang-format"]
```

### Phase 3: Gamification

```bash
cpm status
# 🎮 Level 1: Managed (Score: 65/100)
# 
# ✓ Security basics (20/20)
# ✓ Type safety (15/15)
# ⚠ Test coverage (15/30) — need 80% for Level 2
# ✗ Documentation (0/15) — missing doxygen
#
# Next level: Add 3 checks to reach Level 2
# 1. make coverage (15 points)
# 2. make docs (15 points)
# 3. make complexity (10 points)

cpm level up
# 🎉 Unlocked Level 2: Defined!
# New checks available:
# - Architecture validation
# - Complexity limits
# - Dependency analysis
```

## Why C++ Core?

1. **Performance**: Check execution moet snel zijn
2. **Portability**: Single binary, no runtime dependencies
3. **Dogfooding**: CPM gebruikt zichzelf
4. **Embeddable**: Kan in andere tools geïntegreerd worden

## Why .mk Files?

Makefile includes (`.mk`) zijn **optioneel** voor backwards compatibility:

```makefile
# Old way: include cpm Makefiles
include ../cpm/lib/make/common.mk

# New way: delegate to cpm binary
check:
	@cpm check
```

Maar `.mk` files blijven nuttig voor:

- Gradual migration
- Custom targets
- Integration met bestaande Makefiles

## Training Wheels (Level 0.3)

De eerste stap uit anarchy:

### Step 1: Document Why

```bash
cpm check training-wheels-1
# ✗ No ADR for last 3 commits
# ✗ Commit messages missing context
#
# Fix: cpm adr new "reason for change"
```

### Step 2: Define Acceptance Criteria

```bash
cpm check training-wheels-2
# ✗ No acceptance criteria in ADR-042
#
# Fix: Add ## Acceptance Criteria section
```

### Step 3: Automated Verification

```bash
cpm check training-wheels-3
# ✗ Acceptance criteria not checked
#
# Fix: Add check script that validates criteria
```

**Naam:** "Training Wheels" (Nederlands: "Zijwieltjes")

## Registry Evolution

Van JSON naar TOML met levels:

```toml
[checks.gitleaks]
tier = "pre-commit"
level = 1  # Required for Level 1 (Managed)
category = "security"
autofix = "none"
points = 20

[checks.coverage]
tier = "ci"
level = 2  # Required for Level 2 (Defined)
category = "quality"
autofix = "none"
points = 30
threshold = 80  # 80% coverage needed

[checks.mutation]
tier = "ci"
level = 4  # Required for Level 4 (Optimizing)
category = "quality"
autofix = "none"
points = 50
```

## Commands

```bash
# Initialization
cpm init --mode=prototype          # Level 0
cpm init --mode=mvp                # Level 0.3 (Training Wheels)
cpm init --mode=production         # Level 1

# Level management
cpm status                         # Show current level + score
cpm level up                       # Add next level checks
cpm level down                     # Remove highest level checks
cpm level set 2                    # Jump to specific level

# Mode switching
cpm mode prototype                 # Disable most checks
cpm mode production                # Enable production checks
cpm mode maintenance               # Add maintenance checks
cpm mode dr                        # Add disaster recovery checks
cpm mode sla                       # Add SLA monitoring

# Check execution
cpm check                          # Run all checks for current level
cpm check --tier=pre-commit        # Run specific tier
cpm check --level=2                # Run up to level 2

# Registry management
cpm skip gitleaks "refactoring"    # Skip temporarily
cpm unskip gitleaks                # Re-enable
cpm list                           # Show all checks + status
```

## Success Metrics

- **Adoption**: 10+ repos using CPM
- **Gamification**: Users actively level up
- **Community**: Adapters for 5+ languages
- **Quality**: Average CMMI level 2+ across repos
- **Speed**: Check execution < 3s for Level 1

## Migration Path

### From llama-cli Makefile

```bash
cd llama-cli
cpm import makefile               # Analyze Makefile
cpm init --from-makefile          # Generate cpm.toml
cpm check                         # Verify parity
make → cpm                        # Gradual replacement
```

### From workspace-tui

```bash
cd workspace-tui
cpm import registry               # Import checks-registry.json
cpm init --from-registry          # Generate cpm.toml
cpm check                         # Verify parity
```

## Open Questions

1. **C++ vs Rust?** Rust heeft betere package management (cargo)
2. **Plugin system?** Hoe laden we language adapters?
3. **Registry format?** TOML vs JSON vs YAML?
4. **Scoring algorithm?** Hoe berekenen we points?
5. **Community?** Hoe faciliteren we adapter development?

## References

- ADR-001: Original C-only concept (superseded)
- ADR-002: Feature parity analysis
- ADR-004: Centralized UI pattern
- ADR-005: Check registry pattern
- CMMI framework: <https://cmmiinstitute.com/>
- V-Model: <https://en.wikipedia.org/wiki/V-Model>
