# Design: Generic Duplicate Detection

**Status:** function/file-variable detection implemented; literal detection designed (not yet built)
**Date:** 2026-08-31
**Related:** ADR-170 (origin), ADR-166 (rule engine — future host)

## Purpose

Detect copy-paste in a codebase without hardcoded, project-specific knowledge.
Works on any repository `cpm` scans, not just cpm itself. Language-agnostic where
the source model allows (see [Language support](#language-support)).

Originated in ADR-170: a portability shim (`strcasestr`) was found copy-pasted
across two files. A hardcoded rule for known shim names was rejected because it
only works on cpm. This generic detector catches that case — and any other
copy-paste — with zero project-specific configuration.

## Architecture: a Unix-style pipeline

All duplicate detection shares one composable pipeline. Each stage is a separate
function so the logic can migrate into the declarative rule engine (ADR-166)
once it grows pipeline operators, with no behavioural change:

```
extract | normalize | group_by(hash) | filter(count > 1, files >= N) | report
```

| Stage | Function | Responsibility |
|-------|----------|----------------|
| extract | `extract_symbols()` | Pull candidate items (functions, file-vars, literals) from one file |
| normalize | `normalize_body()` | Canonicalise so formatting differences don't matter |
| group_by | `find_duplicate_symbols()` | Bucket by (kind, body_hash, exact_body) |
| filter | (in group_by) | Keep groups with ≥2 members spanning ≥2 files |
| report | (in group_by) | Emit one `DupFinding` per duplicated group |

Implementation: `src/analysis/dup_symbols.{h,cpp}`. Zero external dependencies;
reuses `analysis/tokenizer` to strip comments and strings before comparison.

## Implemented: function & file-variable duplication

- **What:** functions (and file-scope variables) whose *normalized body* is
  byte-identical across two or more files.
- **How:** brace-based extraction over comment/string-stripped source. A function
  is `<identifier> ( ... ) [qualifiers] { ... balanced braces ... }`.
- **Normalization:** comments and strings removed (tokenizer), all whitespace
  dropped, single spaces reinserted only at identifier/number boundaries. So
  `x*2` and `x * 2` compare equal; `int x` and `intx` do not.
- **False-positive guards:** trivial bodies (`{}`, ≤4 chars) ignored; duplication
  must span ≥2 distinct files (a repeated body in one file is not flagged).
- **Severity:** warning. Never fails the gate. Suppress with
  `[checks] dup-symbols.enabled = false`.
- **Integration:** `run_dup_symbols()` in `checks.cpp`, run by `cpm check` and
  Tier 2 of `cpm check --full`.

Body-hash matching (not name matching) avoids false positives from overloads,
`main`, or unrelated same-named statics: two symbols are duplicates only if their
normalized bodies are identical.

## Language support

| Language | Comment/string strip (tokenizer) | Function extractor | Status |
|----------|:-:|:-:|--------|
| C / C++ / headers | ✅ | ✅ brace-based | **active** (`DUP_EXTENSIONS`) |
| Java, C#, Go, Rust | ✅ | ✅ brace-based (same grammar shape) | **easy add** — extend `DUP_EXTENSIONS` |
| JS / TS / JSX / TSX | ✅ | ⚠️ partial — see below | needs arrow-function support |
| Python | ✅ | ❌ indent-based, not braces | needs an indent-aware extractor |

`DUP_EXTENSIONS` is currently limited to the C family out of caution. The
brace-based extractor works for every curly-brace language for *classic function
declarations*, but was empirically found to have gaps:

- **Java, C#, Go, Rust**: method/func declarations follow the
  `name(args) { body }` shape → work as-is. One-line extension.
- **JS / TS**: `function greet() {}` is detected, but **arrow functions**
  (`const add = (a, b) => { ... }`) are **not** — the extractor keys on
  `identifier ( ) {`, and an arrow has `=>` between `)` and `{`. Since arrow
  functions dominate modern JS/TS, enabling `.ts/.js` requires teaching the
  extractor the `) =>  {` form (small change, needs tests). *Verified by probe
  on 2026-08-31: `function` form extracted, arrow form missed.*
- **Python**: block structure is indentation, not braces → genuinely different
  extractor required.

## Designed (not yet built): literal duplication

Same pipeline, a different `extract` stage.

### What

String and numeric literals that repeat across the codebase — the classic
"magic value" smell (a URL, config key, error message, or magic number pasted in
many places instead of a named constant).

### Extract stage

The tokenizer already *locates* string/number literals (it currently replaces
them with spaces). Invert that: emit each literal with its file and line instead
of erasing it. Numeric literals are scanned separately (the tokenizer only tracks
strings today), matching `[0-9]` runs outside identifiers.

### Why it needs stricter filtering than functions

Duplicate function bodies are almost always a genuine defect. Duplicate literals
are *often legitimate* (the same error string, the same HTTP status). Signal-to-
noise is the whole design problem, so literal detection needs:

1. **Minimum length** — strings shorter than ~4 chars are ignored.
2. **Exclusion list** — never report:
   - empty / whitespace-only strings (`""`, `" "`, `"\n"`, `"\t"`)
   - common trivial numbers (`-1, 0, 1, 2`) and, optionally, powers of two
   - format-only strings (`"%s"`, `"%d"`, `"{}"`) — configurable
   - single punctuation (`"/"`, `","`, `":"`)
3. **Higher threshold** — report from 3+ occurrences (not 2), tunable via config.
4. **Optional "magic only" mode** — numbers outside `{-1,0,1,2}`; strings that
   look like URLs, paths, keys, or messages (length + word-char heuristic).

### Config sketch (cpm.toml)

```toml
[checks.dup-literals]
enabled = true
min-length = 4          # ignore shorter strings
min-occurrences = 3     # report from N copies
ignore = ["%s", "%d", "{}", "/", ","]   # extra literals to skip
numbers = "magic-only"  # "all" | "magic-only" | "off"
```

### New types

```cpp
enum class LiteralKind { String, Number };

struct Literal {
  LiteralKind kind;
  std::string value;     // canonical text of the literal
  std::string file;
  int line;
};

// extract stage
std::vector<Literal> extract_literals(const std::string& content,
                                      const std::string& extension,
                                      const std::string& file);

// filter/report — mirrors find_duplicate_symbols, adds threshold + exclusions
std::vector<DupFinding> find_duplicate_literals(const std::vector<Literal>& lits,
                                                const LiteralOptions& opts);
```

`DupFinding` is reused (add types `"duplicate-string"` / `"duplicate-number"`).

### Effort

~1–1.5h. The extract stage (literals from the tokenizer) is the bulk; group /
filter / report are shared with the existing function detector. The exclusion
list and threshold are the design-sensitive parts, not the code.

## Future: migration into the rule engine (ADR-166)

Once the rule engine supports composable, cross-file pipeline operators, both
detectors become declarative `.rule` definitions:

```
extract:functions | normalize:body | group-by:hash | filter:count>1,files>=2 | report
extract:literals  | filter:min-len,exclusions      | group-by:value | filter:count>=3 | report
```

The C++ modules become the reference implementation and can be retired or kept as
a fast path. No behavioural change is expected at migration.
