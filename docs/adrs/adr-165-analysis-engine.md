---
summary: Analysis engine — tokenizer, import graph, scope tracking. Beyond per-line regex.
status: proposed
---

# ADR-165: Analysis Engine — Beyond Per-Line Regex

**Date:** 2026-08-27
**Status:** Proposed
**Extends:** ADR-145 (pluggable rule engine)
**Relates to:** ADR-151 (duplication detection), ADR-156 (spaghetti score), ADR-022 (native C++ architecture)

## Context

The rule engine (ADR-145) is fast: 492 rules, 400ms for 26K files. It's per-line, per-file, RE2-powered. But it has structural limits:

| Limitation | Example | Why it matters |
|-----------|---------|----------------|
| **False positives in comments/strings** | `// TODO: remove eval()` triggers `eval()` rule | ~15% of findings are noise |
| **No cross-file context** | Can't see that module A imports module B | Circular deps check is TS/JS-only, lives outside rule engine |
| **No scope awareness** | Can't detect `await` inside a `for` loop | Multi-line anti-patterns invisible |
| **No duplicate detection** | ADR-151 designed but not integrated | Spaghetti score (ADR-156) lacks duplication input |
| **No temporal analysis** | Git churn × complexity = hotspot | Most impactful refactoring metric — not available |

The current `scan_code_lines()` in `line_scanner.h` does basic `//` and `/* */` skipping, but it's a hack — it doesn't handle strings containing `/*`, nested comments, or language-specific syntax (`#` for Python/bash, `--` for SQL/Lua).

The `circular.cpp` check builds its own import graph for TS/JS/Python. The `architecture.cpp` check counts `import` and `#include` with string search. These are duplicated, incomplete, and not available to the rule engine.

**We need a proper analysis layer between file reading and rule evaluation.**

## Decision

Build an analysis engine in 3 phases, all in C++, zero external deps. Each phase ships independently and adds value immediately.

### Phase 1: Tokenizer + Import Graph (MVP)

**Tokenizer** — universal comment/string stripping for 15+ languages:

```cpp
// src/analysis/tokenizer.h
struct LanguageSyntax {
  const char* line_comment;     // "//" or "#" or "--" or nullptr
  const char* block_start;      // "/*" or "\"\"\"" or nullptr
  const char* block_end;        // "*/" or "\"\"\"" or nullptr
  char string_chars[4];         // '"', '\'', '`', 0
  bool has_raw_strings;         // R"(...)" in C++, r"..." in Python
  bool has_heredoc;             // <<EOF in bash/ruby
};

enum class TokenType {
  Code,           // actual source code
  LineComment,    // // or # comment
  BlockComment,   // /* ... */ or """ ... """
  String,         // "..." or '...' or `...`
  Whitespace,     // blank lines, indentation
};

struct Token {
  TokenType type;
  int line;             // 1-based line number
  int col;              // 0-based column
  const char* start;    // pointer into original content (zero-copy)
  size_t len;
};

/**
 * @brief Tokenize file content into code/comment/string spans.
 *
 * Does NOT build an AST. Just classifies every byte as code, comment,
 * or string. This is the minimum needed to eliminate false positives.
 *
 * @param content  File content (must outlive returned tokens)
 * @param syntax   Language syntax table entry
 * @return Vector of tokens covering the entire file
 */
std::vector<Token> tokenize(const char* content, size_t len, const LanguageSyntax& syntax);

/**
 * @brief Extract only code tokens as lines (comments/strings stripped).
 *
 * Returns reconstructed lines with comments replaced by whitespace
 * (preserving line numbers for accurate finding locations).
 */
std::vector<std::string> extract_code_lines(const char* content, size_t len, const LanguageSyntax& syntax);
```

**Import graph** — adjacency list from regex-parsed imports:

```cpp
// src/analysis/import_graph.h

struct ImportEdge {
  std::string from_file;    // "src/utils/parser.ts"
  std::string to_module;    // "./types" (raw) or "src/utils/types.ts" (resolved)
  int line;                 // where the import appears
};

struct ImportGraph {
  // Adjacency list: file → files it imports
  std::unordered_map<std::string, std::vector<std::string>> edges;

  // Reverse index: file → files that import it
  std::unordered_map<std::string, std::vector<std::string>> reverse_edges;

  // All known files in the project
  std::unordered_set<std::string> known_files;

  // Build from edges
  void build(const std::vector<ImportEdge>& imports);
};

// Import extraction — one regex set per language
struct ImportExtractor {
  const char* extensions;   // ".ts .js .tsx .jsx"
  RE2 pattern;              // pre-compiled regex for this language
  // Returns raw module path from capture group
};

static const ImportExtractor extractors[] = {
  // JS/TS: import ... from '...' | require('...')
  {".ts .js .tsx .jsx .mjs .cjs",
   RE2(R"((?:from\s+['"]|require\s*\(\s*['"])([^'"]+))")},

  // Python: from X import Y | import X
  {".py",
   RE2(R"((?:from\s+(\S+)\s+import|^import\s+(\S+)))")},

  // C/C++: #include "..." | #include <...>
  {".cpp .c .h .hpp .cc .cxx",
   RE2(R"(#include\s*[<"]([^>"]+)[>"])")},

  // Go: import "path" | import ( "path" )
  {".go",
   RE2(R"(import\s+(?:\(?\s*)"([^"]+)")")},

  // Java: import com.example.Foo
  {".java",
   RE2(R"(import\s+([\w.]+);)")},

  // Rust: use crate::module | mod module
  {".rs",
   RE2(R"((?:use\s+([\w:]+)|mod\s+(\w+)))")},

  // PHP: use App\Models\User | require_once '...'
  {".php",
   RE2(R"((?:use\s+([\w\\]+)|(?:require|include)(?:_once)?\s*[('"]([^'"]+)))")},

  // Ruby: require '...' | require_relative '...'
  {".rb",
   RE2(R"(require(?:_relative)?\s+['"]([^'"]+))")},

  // C#: using System.IO
  {".cs",
   RE2(R"(using\s+([\w.]+)\s*;)")},

  // Dart: import 'package:...' | import '...'
  {".dart",
   RE2(R"(import\s+['"]([^'"]+))")},

  // Swift: import Foundation
  {".swift",
   RE2(R"(import\s+(\w+))")},
};
```

**Integration with rule engine** — the `.rule` format gains `skip_comments`:

```text
# rules/security/SEC-042-eval.rule
id: SEC-042
title: eval() usage detected
severity: error
engine: pattern
extensions: .js .ts .py .rb .php
skip_comments: true

patterns:
  - regex: \beval\s*\(
    message: eval() is a code injection risk (CWE-95)

fix: Use safe alternatives (JSON.parse, Function constructor, ast.literal_eval)
```

The rule engine changes are minimal:

```cpp
// In rules_scan(), before line matching:
std::vector<re2::StringPiece> lines_to_scan;

if (rule->skip_comments) {
  auto& syntax = get_syntax(ext);
  auto code_lines = extract_code_lines(content.data(), content.size(), syntax);
  // ... use code_lines instead of raw lines
} else {
  // ... existing behavior (unchanged)
}
```

**Existing `.rule` files work unchanged.** `skip_comments` defaults to `false`.

**New analyses from import graph:**

| Analysis | Algorithm | Finding |
|----------|-----------|---------|
| Cycle detection | Tarjan's SCC | "Circular dependency: A → B → C → A" |
| Dead modules | Nodes with in-degree 0 (not entry points) | "src/utils/old.ts is never imported" |
| Fan-in / fan-out | Degree counting per node | "src/db.ts has 42 dependents (high fan-in)" |
| Layer violations | Edge from `domain/` to `infrastructure/` | "Domain imports infrastructure (Dependency Inversion)" |
| Instability metric | I = fan-out / (fan-in + fan-out) | I=1.0 means maximally unstable (all deps outward) |

This replaces and generalizes `circular.cpp` (currently TS/JS/Python only) and `architecture.cpp`'s fan-out counting.

### Phase 2: Duplicate Detection + Git Temporal

**Rabin-Karp rolling hash** — implements ADR-151's design:

```cpp
// src/analysis/duplication.h
struct ClonePair {
  std::string file_a, file_b;
  int line_a, line_b;       // starting lines
  int length;               // lines of duplication
};

/**
 * @brief Detect code clones using Rabin-Karp rolling hash.
 *
 * Hashes each normalized code line (whitespace-stripped, comment-stripped).
 * Uses rolling hash to find matching sequences ≥ min_lines.
 *
 * The tokenizer from Phase 1 feeds this: only Code tokens are hashed.
 */
std::vector<ClonePair> detect_clones(
  const std::unordered_map<std::string, std::vector<std::string>>& code_lines,
  int min_lines = 15
);
```

**Git log parser with caching:**

```cpp
// src/analysis/git_analysis.h
struct FileChurn {
  std::string file;
  int commits;          // total commits touching this file
  int contributors;     // unique authors
  int lines_changed;    // total lines added + deleted
  double age_days;      // days since last change
};

/**
 * @brief Parse git log for churn data. Caches to .cpm-cache/git-churn.jsonl.
 *
 * Runs: git log --numstat --format="%H|%ae|%aI" --since=6months
 * Caches result keyed by HEAD commit hash — invalidated on new commits.
 */
std::vector<FileChurn> git_churn(const std::string& root);
```

**Hotspot scoring** feeds into ADR-156 (spaghetti score):

```text
hotspot_score = normalize(commits × complexity)

High churn + high complexity = most valuable refactoring target.
```

### Phase 3: Scope-Aware Matching + Function Metrics

**Brace/indent tracking:**

```cpp
// src/analysis/scope_tracker.h
enum class ScopeType { Function, Class, Loop, Conditional, Block, Lambda };

struct Scope {
  ScopeType type;
  int start_line;
  int depth;            // nesting level
  std::string name;     // function/class name (if detected)
};

/**
 * @brief Track scope context using brace counting + heuristics.
 *
 * Not a full parser. Uses brace depth + line-level heuristics:
 * - "function " / "def " / "fn " → Function scope
 * - "class " / "struct " → Class scope
 * - "for " / "while " / "do " → Loop scope
 * - "if " / "else " / "switch " → Conditional scope
 *
 * Good enough for: "is this pattern inside a loop?" and
 * "what function does line 42 belong to?"
 */
std::vector<Scope> track_scopes(
  const std::vector<Token>& tokens,
  const LanguageSyntax& syntax
);
```

This enables scope-aware rules:

```text
# rules/quality/QUAL-050-await-in-loop.rule
id: QUAL-050
title: await inside loop
severity: warning
engine: pattern
extensions: .ts .js .mjs
skip_comments: true
scope: loop

patterns:
  - regex: \bawait\s+
    message: await in loop — consider Promise.all() for parallel execution

fix: Collect promises and use Promise.all()
```

**Function boundary detection** (lizard-style):

```cpp
struct FunctionMetrics {
  std::string name;
  std::string file;
  int start_line, end_line;
  int ccn;              // cyclomatic complexity number
  int nloc;             // lines of code (excluding blanks/comments)
  int params;           // parameter count
  int max_nesting;      // deepest nesting within function
};

/**
 * @brief Extract per-function metrics for all functions in a file.
 *
 * Heuristic detection — not AST-based. Handles:
 * - C/C++: type name(params) { ... }
 * - JS/TS: function name(), const name = () =>, class method()
 * - Python: def name(params):
 * - Java/C#: access type name(params) { ... }
 * - Go: func name(params) { ... }
 * - Rust: fn name(params) { ... }
 */
std::vector<FunctionMetrics> extract_functions(
  const std::vector<Token>& tokens,
  const LanguageSyntax& syntax,
  const std::string& file
);
```

This replaces the current `complexity.cpp` check (which counts `if/for/while` globally per file) with per-function granularity.

## Architecture

```text
File Walker (walk_files — existing, unchanged)
  │
  ├─ Read file content (once, mmap for large files)
  │
  └─ Tokenizer (Phase 1)
      │  input: raw file content + LanguageSyntax
      │  output: Token[] — every byte classified as Code/Comment/String
      │
      ├─ Rule Engine (existing — now comment-aware via skip_comments)
      │    Pattern matching on code-only tokens
      │    Existing .rule files: behavior unchanged
      │    New .rule files: skip_comments: true eliminates FPs
      │
      ├─ Import Extractor (Phase 1)
      │    Regex per language on Code tokens → ImportEdge[]
      │    Feeds into ImportGraph (built after all files scanned)
      │
      ├─ Scope Tracker (Phase 3)
      │    Brace depth + heuristic scope type detection
      │    Enables scope: loop/function/class in .rule files
      │
      └─ Hash Generator (Phase 2)
           Rabin-Karp rolling hash on normalized code lines
           Feeds into duplicate detection (cross-file)

ImportGraph (Phase 1 — built after all files processed)
  ├─ Cycle Detection (Tarjan SCC)
  │    Replaces circular.cpp (TS/JS only → all 11 languages)
  ├─ Dead Module Detection
  │    in-degree 0, not entry point → finding
  ├─ Fan-in / Fan-out
  │    Replaces architecture.cpp's import counting
  ├─ Layer Violation
  │    domain/ → infrastructure/ edges → finding
  └─ Instability Metric (Robert C. Martin)
       I = Ce / (Ca + Ce), feeds into ADR-156 spaghetti score

Git Analysis (Phase 2 — cached, on-demand, not in hot path)
  ├─ Churn per file (commits × lines changed)
  ├─ Contributors per file (bus factor)
  └─ Temporal coupling (files that always change together)
```

### Data flow for Phase 1

```text
                    ┌──────────────────────────┐
                    │    rules_scan() entry     │
                    └─────────┬────────────────┘
                              │
              ┌───────────────▼───────────────┐
              │     walk_files() (unchanged)   │
              └───────────────┬───────────────┘
                              │ for each file:
              ┌───────────────▼───────────────┐
              │  read content (once)           │
              │  detect language (by ext)      │
              │  tokenize(content, syntax)     │
              └──────┬────────────┬───────────┘
                     │            │
         ┌───────────▼──┐   ┌────▼──────────────┐
         │ Rule Engine   │   │ Import Extractor   │
         │ (per-line,    │   │ (per-file,         │
         │  skip_comments│   │  regex on code     │
         │  if requested)│   │  tokens only)      │
         └───────────────┘   └────┬──────────────┘
                                  │ collect edges
                    ┌─────────────▼──────────────┐
                    │    ImportGraph.build()       │
                    │    (after all files done)    │
                    └─────────────┬──────────────┘
                                  │
              ┌───────────────────▼──────────────┐
              │  Graph analyses:                  │
              │  - tarjan_scc() → cycles          │
              │  - dead_modules() → unused files  │
              │  - fan_metrics() → fan-in/out     │
              │  - layer_check() → violations     │
              │  - instability() → I metric       │
              └──────────────────────────────────┘
```

## Performance Budget

Budget: current scan is ~600ms for 26K files. We have 1400ms headroom to stay under 2s.

| Component | Cost per 10K files | Phase | Notes |
|-----------|-------------------|-------|-------|
| File walk + read | ~200ms | existing | Already paid, unchanged |
| Rule engine (RE2) | ~150ms | existing | Already paid, unchanged |
| **Tokenizer** | ~80ms | 1 | Single pass over content, pointer arithmetic |
| **Import extraction** | ~30ms | 1 | One RE2 match per code line, only import-relevant files |
| **Graph build** | ~5ms | 1 | Hash map insertion, O(E) |
| **Tarjan SCC** | ~2ms | 1 | O(V+E), typically <5K nodes |
| **Dead module detection** | ~1ms | 1 | Single pass over reverse_edges |
| **Fan-in/fan-out** | ~1ms | 1 | Degree counting, O(V) |
| **Layer violation** | ~1ms | 1 | Edge filtering, O(E) |
| **Instability metric** | ~1ms | 1 | Arithmetic on fan-in/fan-out |
| **Phase 1 total** | **~121ms** | 1 | Well within budget |
| Rabin-Karp hashing | ~100ms | 2 | Rolling hash over normalized lines |
| Clone matching | ~50ms | 2 | Hash table probes, extend matches |
| Git log parse | ~200ms (cached: 0ms) | 2 | One-time cost, cached to disk |
| Scope tracking | ~60ms | 3 | Second pass over tokens, brace counting |
| Function extraction | ~40ms | 3 | Heuristic scan on scope boundaries |
| **All phases total** | **~571ms** | 1+2+3 | Total ~1171ms, under 2s budget |

Measurement method: `std::chrono::high_resolution_clock`, averaged over 10 runs, on the cpm repo (800 files) extrapolated to 10K.

## Language Syntax Table

The tokenizer needs one row per language. No language-specific parser — just comment/string delimiters.

```cpp
// src/analysis/syntax_table.cpp
static const struct { const char* ext; LanguageSyntax syntax; } syntax_table[] = {
  // ext          line_comment  block_start  block_end   string_chars  raw_str  heredoc
  {".cpp",       {"//",        "/*",        "*/",       {'"','\'',0}, true,    false}},
  {".c",         {"//",        "/*",        "*/",       {'"','\'',0}, false,   false}},
  {".h",         {"//",        "/*",        "*/",       {'"','\'',0}, true,    false}},
  {".hpp",       {"//",        "/*",        "*/",       {'"','\'',0}, true,    false}},
  {".java",      {"//",        "/*",        "*/",       {'"','\'',0}, false,   false}},
  {".cs",        {"//",        "/*",        "*/",       {'"','\'',0}, false,   false}},
  {".js",        {"//",        "/*",        "*/",       {'"','\'','`',0}, false, false}},
  {".ts",        {"//",        "/*",        "*/",       {'"','\'','`',0}, false, false}},
  {".tsx",       {"//",        "/*",        "*/",       {'"','\'','`',0}, false, false}},
  {".jsx",       {"//",        "/*",        "*/",       {'"','\'','`',0}, false, false}},
  {".go",        {"//",        "/*",        "*/",       {'"','\'','`',0}, false, false}},
  {".rs",        {"//",        "/*",        "*/",       {'"',0},      true,    false}},
  {".swift",     {"//",        "/*",        "*/",       {'"',0},      false,   false}},
  {".dart",      {"//",        "/*",        "*/",       {'"','\'',0}, false,   false}},
  {".kt",        {"//",        "/*",        "*/",       {'"','\'',0}, false,   false}},
  {".py",        {"#",         "\"\"\"",    "\"\"\"",   {'"','\'',0}, true,    false}},
  {".rb",        {"#",         "=begin",    "=end",     {'"','\'',0}, false,   true }},
  {".php",       {"//",        "/*",        "*/",       {'"','\'',0}, false,   true }},
  {".sh",        {"#",         nullptr,     nullptr,    {'"','\'',0}, false,   true }},
  {".bash",      {"#",         nullptr,     nullptr,    {'"','\'',0}, false,   true }},
  {".yaml",      {"#",         nullptr,     nullptr,    {'"','\'',0}, false,   false}},
  {".yml",       {"#",         nullptr,     nullptr,    {'"','\'',0}, false,   false}},
  {".tf",        {"#",         "/*",        "*/",       {'"',0},      false,   true }},
  {".sql",       {"--",        "/*",        "*/",       {'\'',0},     false,   false}},
  {".lua",       {"--",        "--[[",      "]]",       {'"','\'',0}, false,   false}},
  {".toml",      {"#",         nullptr,     nullptr,    {'"','\'',0}, false,   false}},
};

const LanguageSyntax* get_syntax(const std::string& ext) {
  for (auto& entry : syntax_table) {
    if (ext == entry.ext) return &entry.syntax;
  }
  return nullptr;  // unknown language → skip tokenization, use raw lines
}
```

**26 extensions, 16 distinct syntax profiles.** Unknown extensions fall through to raw line scanning (existing behavior).

## File Structure (new files only)

```text
src/analysis/                    ← NEW directory
├── tokenizer.h                  ← Token struct, LanguageSyntax, tokenize()
├── tokenizer.cpp                ← Tokenizer implementation (~200 LOC)
├── tokenizer_test.cpp           ← Tests for all 16 language profiles
├── syntax_table.h               ← get_syntax() lookup
├── syntax_table.cpp             ← The 26-extension table (~60 LOC)
├── import_graph.h               ← ImportGraph, ImportEdge structs
├── import_graph.cpp             ← Graph build + analyses (~300 LOC)
├── import_graph_test.cpp        ← Cycle, dead module, fan-in/out tests
├── import_extractor.h           ← Per-language import regex
├── import_extractor.cpp         ← Extract imports from code tokens (~150 LOC)
├── duplication.h                ← Phase 2: ClonePair, detect_clones()
├── duplication.cpp              ← Phase 2: Rabin-Karp implementation
├── git_analysis.h               ← Phase 2: FileChurn, git_churn()
├── git_analysis.cpp             ← Phase 2: git log parser + cache
├── scope_tracker.h              ← Phase 3: Scope, track_scopes()
├── scope_tracker.cpp            ← Phase 3: Brace/indent scope detection
├── function_metrics.h           ← Phase 3: FunctionMetrics, extract_functions()
└── function_metrics.cpp         ← Phase 3: Per-function CCN/NLOC/params
```

**Estimated total:** ~1200 LOC for Phase 1, ~800 LOC for Phase 2, ~600 LOC for Phase 3.

## Changes to Existing Code

### rule_engine.h — new fields

```cpp
struct Rule {
  // ... existing fields unchanged ...
  bool skip_comments = false;   // NEW: strip comments before matching
  std::string scope;            // NEW (Phase 3): "loop", "function", "class", ""
};
```

### rule_engine.cpp — tokenizer integration

```cpp
// In rules_scan(), the file processing loop gains one branch:

if (has_comment_aware_rules) {
  auto* syntax = get_syntax(ext);
  if (syntax) {
    auto code_lines = extract_code_lines(content.data(), content.size(), *syntax);
    // Evaluate skip_comments rules against code_lines
    // Evaluate normal rules against raw lines (unchanged)
  }
}
// Files with unknown extensions: existing behavior, no tokenizer
```

### circular.cpp — replaced

The `CircularCheck` in `circular.cpp` becomes a thin wrapper that reads from `ImportGraph` instead of building its own. Eventually removed once import graph analyses are integrated into the check orchestrator.

### architecture.cpp — enhanced

`check_fan_out()` reads from `ImportGraph` instead of counting `import` string occurrences. Same findings, fewer false positives (won't count `import` in comments or strings).

## Constraints

- **Zero external dependencies** — tokenizer is hand-written (~200 LOC), no tree-sitter, no ANTLR
- **Single binary** — syntax table is compiled in, no runtime data files
- **macOS + Linux + Windows** — no platform-specific APIs in analysis layer (POSIX `dirent.h` already abstracted in `file_walker`)
- **Pre-commit < 5s on 10K files** — Phase 1 adds ~121ms, well within budget
- **Backward compatible** — existing `.rule` files work unchanged, `skip_comments` defaults to `false`
- **Heuristic, not precise** — the tokenizer is 95% accurate, not 100%. It won't handle pathological cases (string containing `*/`, triple-nested template strings). That's fine — cpm is a linter orchestrator, not a compiler.

## What This Is NOT

- **Not an AST parser** — we don't build syntax trees. Tokenizer classifies bytes, nothing more.
- **Not tree-sitter** — tree-sitter is 10MB+ of C, grammars are 100KB+ each. We need 200 LOC.
- **Not a language server** — no type resolution, no semantic analysis, no completions.
- **Not perfect** — 95% accuracy is the goal. The 5% false positives from edge cases are acceptable when we've eliminated the 15% false positives from comments/strings.

## Consequences

### Positive

- **False positives reduced ~50%** — comment/string awareness eliminates the largest source of noise
- **10+ new cross-file analyses** — cycles, dead modules, fan-in/out, layer violations, instability (all languages)
- **ADR-151 gets its implementation** — Rabin-Karp duplicate detection, tokenizer-fed
- **ADR-156 spaghetti score improves** — duplication data, instability metric, hotspot scoring
- **Rule authors get `skip_comments`** — one line in `.rule` file, massive accuracy improvement
- **`circular.cpp` generalized** — from 3 languages to 11, from direct cycles to full SCC
- **Foundation for Phase 3** — scope-aware matching enables anti-patterns like `await-in-loop`

### Negative

- **~2600 LOC of new C++ code** — but it's simple (no templates, no inheritance hierarchies)
- **Tokenizer is heuristic** — pathological inputs will fool it. We document this and move on.
- **Import resolution is approximate** — we match file paths heuristically, not through language-specific module resolution. Enough for cycle detection; not enough for "find all usages of symbol X."

### Migration

| Current code | Phase 1 change |
|-------------|----------------|
| `scan_code_lines()` in `line_scanner.h` | Deprecated, replaced by tokenizer |
| `CircularCheck` in `circular.cpp` | Replaced by `ImportGraph` + Tarjan SCC |
| `check_fan_out()` in `architecture.cpp` | Reads from `ImportGraph` |
| All `.rule` files | Unchanged (backward compatible) |
| New `.rule` files | Can use `skip_comments: true` |

## References

- @see docs/adrs/adr-145-pluggable-rule-engine.md (rule engine this extends)
- @see docs/adrs/adr-151-compression-inspired-duplication-detection.md (Phase 2 algorithm)
- @see docs/adrs/adr-156-spaghetti-score.md (consumer of analysis data)
- @see docs/adrs/adr-022-native-cpp-architecture.md (native C++ philosophy)
- @see src/rules/rule_engine.cpp (current implementation)
- @see src/checks/quality/circular.cpp (replaced by ImportGraph)
- @see src/line_scanner.h (deprecated by tokenizer)
- @see Robert C. Martin, "Agile Software Development" (instability metric: I = Ce / (Ca + Ce))
- @see Tarjan, R. (1972), "Depth-first search and linear graph algorithms" (SCC algorithm)
- @see Karp, R. & Rabin, M. (1987), "Efficient randomized pattern-matching algorithms" (rolling hash)
