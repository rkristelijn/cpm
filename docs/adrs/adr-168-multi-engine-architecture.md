# ADR-168: Multi-Engine Architecture — Regex + Tree-sitter + Semgrep + Gitleaks

**Status:** Proposed
**Date:** 2026-08-28
**Deciders:** @rkristelijn
**See also:** ADR-145 (rule engine), ADR-166 (engine extensions), R-029 (production readiness)

## Context

cpm currently has one scanning engine: RE2 regex over lines. This gives ~30% of what a lead developer checks. To reach ~60%, we need structural code understanding. To reach ~75%, we need AST pattern matching.

Three proven open-source tools already solve these problems:

- **Tree-sitter** (MIT) — incremental parser, 100+ languages, C library, ~200KB
- **Semgrep** (LGPL) — AST pattern matching with a developer-friendly DSL
- **Gitleaks** (MIT) — entropy-based secret detection with high-accuracy allowlists

## Decision

cpm becomes an **orchestrator** that unifies multiple analysis engines behind one rule format. Users write the same `.rule` files they write today. cpm selects the right engine internally.

### Three analysis levels

```text
Level 1: Text scanning (regex, RE2)
  ├── pattern, absence, presence, file-absence, file-presence, extract-duplicates
  ├── 875 rules today
  └── Speed: <1s for any project

Level 2: Structural analysis (tree-sitter)
  ├── function-length, nesting-depth, parameter-count, cyclomatic-complexity
  ├── empty-catch, unused-parameter, class-method-count, return-consistency
  └── Speed: ~2-5s for typical project (incremental parsing)

Level 3: Semantic patterns (semgrep-compatible)
  ├── Multi-statement patterns with metavariables ($X, $FUNC, $...ARGS)
  ├── Taint tracking, data flow (semgrep features)
  └── Speed: ~5-15s for typical project
```

### Rule format (unified)

```yaml
# Level 1: regex (current)
id: SEC-038
engine: pattern
target:
  extensions: .ts .js
patterns:
  - regex: createHash\(\s*['"]md5['"]\s*\)
    message: "MD5 is cryptographically broken"

# Level 2: structural (new — tree-sitter powered)
id: QUAL-200
engine: structure
check: function-length
max_statements: 30
target:
  extensions: .ts .js .py .java .go .cpp
message: "Function '{name}' has {count} statements (max {max})"

# Level 3: AST pattern (new — semgrep-compatible)
id: QUAL-300
engine: semgrep
pattern: |
  if ($COND) { return true; } else { return false; }
fix: "return $COND;"
languages: [javascript, typescript, java]
message: "Simplify boolean return"
```

Zero learning curve for level 2 — users write `check: function-length`, not tree-sitter queries. cpm translates internally.

### Built-in structural checks (level 2)

| Check | What | Tree-sitter implementation |
|-------|------|---------------------------|
| `function-length` | Statements per function | Count child statement nodes in function body |
| `nesting-depth` | Max nested if/for/while | Walk tree, track depth counter |
| `parameter-count` | Params per function | Count parameter nodes |
| `cyclomatic-complexity` | Exact McCabe complexity | Count decision points (if/for/while/switch/catch/&&/\|\|) |
| `class-method-count` | Methods per class | Count method_definition children |
| `empty-catch` | Catch with no body | Match catch_clause with empty statement_block |
| `unused-parameter` | Param not used in body | Extract param identifiers, check if used in body |
| `return-consistency` | Mix of return/no-return | Analyze return statements across all paths |
| `single-responsibility` | Function does multiple distinct operations | Count distinct API calls / side effects |

### Secret detection (gitleaks integration)

Current: 80 SECRETS-* rules using regex patterns.
Gap: regex can't do entropy analysis (detecting `aK3x9mP2...` as a potential secret).

Option A: Shell out to gitleaks binary (if installed).
Option B: Port gitleaks' entropy + regex approach to C++ (it's a simple algorithm).
Option C: Keep regex rules, recommend gitleaks alongside.

Recommendation: **Option A first, Option B later.** `cpm check` shells out to gitleaks if installed, falls back to regex rules if not.

## Architecture

```text
cpm binary (static-linked)
├── RE2 (regex engine, ~1.5MB)
├── tree-sitter runtime (parser, ~200KB)
├── tree-sitter grammars (per-language, ~50KB each, bundled for top 10)
└── cpm rule engine (orchestrator)
    ├── rules_scan() — Level 1: regex rules (current)
    ├── ast_scan() — Level 2: tree-sitter structural checks (new)
    └── semgrep_scan() — Level 3: shell out to semgrep if installed (new)

External (optional, shelled out):
├── gitleaks — enhanced secret detection
└── semgrep — advanced AST patterns
```

Binary size estimate: ~4MB (current 402KB + RE2 1.5MB + tree-sitter 200KB + 10 grammars 500KB + overhead).

## Implementation Plan

| Phase | What | Effort |
|-------|------|--------|
| 1 | Static-link RE2 into main binary | 1 week |
| 2 | Add tree-sitter C library + JS/TS/Python grammars | 1 week |
| 3 | Implement 4 structural checks (function-length, nesting, params, complexity) | 2 weeks |
| 4 | Add `engine: structure` to rule parser | 1 week |
| 5 | Shell-out to gitleaks/semgrep if installed | 1 week |
| 6 | Add remaining 5 structural checks | 2 weeks |
| **Total** | | **~8 weeks** |

## Consequences

**Positive:**

- One tool replaces semgrep + gitleaks + custom linters for 80% of use cases
- Users write `.rule` files, not tree-sitter queries or semgrep patterns
- Binary stays self-contained (~4MB, still small)
- Incremental: level 1 works today, levels 2/3 add capability without breaking existing rules

**Negative:**

- Binary grows 10x (402KB → ~4MB)
- Build complexity increases (C + C++ + tree-sitter grammars)
- Maintaining grammars for 10+ languages is ongoing work
- Level 3 (semgrep) still requires external tool

**Neutral:**

- This is the path every serious static analysis tool has taken (SonarQube, Semgrep, DeepSource all use AST)
- Tree-sitter is the de facto standard parser for editor tooling — proven, maintained, fast
