# ADR-166: Rule Engine Extensions — File-Level, Scope, Cross-File, and Conditional Engines

**Status:** Accepted
**Date:** 2026-08-28
**Deciders:** @rkristelijn
**See also:** ADR-145 (pluggable rule engine), ADR-165 (analysis engine / tokenizer)

## Context

The rule engine (ADR-145) supports three engines: `pattern`, `absence`, and `presence`. All three operate on **content within a single file** — they match regex patterns against lines.

Meanwhile, 21 shell-based checks in `checks/` perform project-level analysis that the rule engine cannot express:

| Capability gap | Shell checks that need it | Count |
|---|---|---|
| File existence check (does `README.md` exist?) | readme-structure, pwa, security-headers | 6 |
| Scoped matching (first N lines only) | shell-strict, shell-help, curl-safety | 4 |
| Cross-file reference check (is this .sh referenced anywhere?) | dead-scripts, orphan-docs | 2 |
| Conditional logic (if file A exists, check file B) | security-headers, caching, pwa, hreflang | 6 |
| Aggregation / counting | css-advanced, image-optimization, font-optimization | 3 |

Shell checks are ~100 lines each, require bash, are slow (fork+exec per check), and cannot leverage the rule engine's single-pass file walk or RE2. Migrating them to `.rule` files would make them faster, cross-platform, and consistent with the existing rule corpus (756 rules).

## Decision

Extend the rule engine in four phases, each backwards-compatible. New keys are ignored by older parsers. Each phase unlocks migration of specific shell checks.

### Phase 1: File-level engines + scope

**New engines:**

```
engine: file-absence
```

Reports a finding when a file matching the target specification **does not exist** in the project. No `patterns:` section needed — the rule fires based on file existence alone.

```yaml
# Example: project must have a README.md
id: PROJ-001
title: Missing README.md
severity: error
engine: file-absence
target:
  filenames: README.md
fix: Create a README.md with project description, setup, and usage instructions.
```

```
engine: file-presence
```

Inverse: reports a finding when a file **does** exist (e.g., committed `.env`, `debug.log`).

**Implementation:** After the file walk, build a `set<string>` of all discovered basenames and relative paths. For each `file-absence` rule, check if any walked file matches the target. If none match → finding. For `file-presence`, if any match → finding.

**New target field: `scope`**

```yaml
target:
  extensions: .sh
  scope: 1-10          # only scan lines 1 through 10
```

Limits pattern matching to a line range within each file. This enables checks like "shebang must be on line 1" or "strict mode must appear in the first 10 lines" without false positives from matches deep in the file.

Syntax: `<start>-<end>` (1-indexed, inclusive). Omit for full-file scan (current behavior).

**Implementation:** In the scan loop, clamp `scan_lines` to the specified range before evaluating patterns. ~20 lines of code.

**Shell checks eliminated:** check-shell-strict.sh, check-shell-help.sh, check-curl-safety.sh, check-readme-structure.sh (partial — the "file missing" and "absence of pattern" rules; the counting/template rules stay).

### Phase 2: Cross-file reference engine

**New engine:**

```
engine: unreferenced
```

Reports a finding for each file matching `target` whose **basename is not referenced** in any file matching `search_in`.

```yaml
id: QUAL-050
title: Unreferenced shell script (potential dead code)
severity: info
engine: unreferenced
target:
  extensions: .sh
  exclude_paths: test/ node_modules/ vendor/
search_in:
  extensions: .sh .md .yml .yaml .json .toml .js .ts .py .go .cpp .h .java .tf
  exclude_paths: node_modules/ vendor/ .git/
  match: basename       # search for the filename (not full path)
fix: If unused, remove the script. If needed, reference it from Makefile, docs, or another script.
```

**Implementation:**

1. After the file walk, partition files into `target_files` and `search_files` based on their respective specs.
2. For each `search_file`, read content (already cached from the main scan loop) and extract all referenced basenames into a `set<string>`.
3. For each `target_file`, check if its basename exists in the reference set.
4. If not referenced → finding.

Optimization: the main scan loop already reads every file once. Store content in a `map<string, string>` (path → content) to avoid re-reading. Memory cost is bounded by the existing 1MB-per-file limit.

**Alternative considered:** Integrate with the import graph (ADR-165). Rejected because the import graph models language-specific imports (ES6, Python, Go) while `unreferenced` needs broader text search (any mention of the filename in any file type).

**Shell checks eliminated:** check-dead-scripts.sh, check-orphan-docs.sh.

### Phase 3: Conditional rules

**New engine:**

```
engine: conditional
```

A conditional rule has a `condition` block that gates pattern evaluation:

```yaml
id: WEB-SEC-050
title: Missing security headers in Next.js config
severity: warning
engine: conditional
condition:
  file_exists: next.config.js
target:
  filenames: next.config.js
patterns:
  - regex: Strict-Transport-Security
    message: "next.config.js missing HSTS header"
  - regex: X-Content-Type-Options
    message: "next.config.js missing X-Content-Type-Options header"
fix: Add security headers to next.config.js via the headers() function.
```

**Condition types:**

| Condition | Semantics |
|---|---|
| `file_exists: <path or glob>` | True if at least one file matches |
| `file_absent: <path or glob>` | True if no file matches |
| `content_contains: <literal>` | True if any target file contains the literal |

Conditions can be combined:

```yaml
condition:
  any_of:
    - file_exists: next.config.js
    - file_exists: nuxt.config.ts
    - file_exists: vercel.json
```

**Implementation:** Evaluate conditions against the walked file list before entering the pattern scan loop. If condition is false, skip the rule entirely. ~80 lines.

**Shell checks eliminated:** check-security-headers.sh, check-caching.sh, check-pwa.sh, check-hreflang.sh.

### Phase 4: Aggregation (future)

**Not designed yet.** Aggregation (counting matches, thresholds, percentages) is needed for ~3 checks. These are the most complex and least common. Options to explore:

- `threshold: { min_matches: 3, message: "..." }` on pattern rules
- `engine: count` with `report_if: count > 5`
- Keep these as shell checks or native C++ checks

**Shell checks that remain as shell:** check-structured-data.sh (JSON-LD parsing), check-image-optimization.sh (needs image metadata), check-font-optimization.sh (complex CSS state machine).

## Implementation Notes

### Parser changes

New keys added to the rule parser (all optional, backwards-compatible):

```
scope: <start>-<end>           → RuleTarget.scope_start, scope_end
search_in:                     → Rule.search_in (RuleTarget)
  extensions: ...
  exclude_paths: ...
  match: basename|path
condition:                     → Rule.condition
  file_exists: ...
  file_absent: ...
  content_contains: ...
  any_of: [...]
  all_of: [...]
```

### Performance budget

- Phase 1: Zero overhead for existing rules. Scope adds one comparison per rule per file.
- Phase 2: One extra pass over file contents to build the reference set. O(F × L) where F = search files, L = avg lines. Bounded by existing memory limits.
- Phase 3: Condition evaluation is O(R × F) where R = conditional rules, F = walked files. Negligible compared to regex matching.

### Migration strategy

1. Implement new engine in `rule_engine.cpp`
2. Write equivalent `.rule` file
3. Add test in `rules_test.cpp`
4. Verify finding parity with the shell check
5. Delete the shell check
6. Update check count in README.md

## Consequences

**Positive:**
- ~15 shell checks can be migrated to declarative `.rule` files
- Single-pass scanning (no fork+exec per check)
- Cross-platform (no bash dependency for these checks)
- Consistent output format (JSONL findings, same as all rules)
- Easier to maintain, test, and extend

**Negative:**
- Rule engine complexity increases (~250 lines across 3 phases)
- `rule-scan` binary gains more responsibility
- ~3 shell checks cannot be migrated (need external tools or complex parsing)

**Neutral:**
- The `.rule` format grows but remains a flat key:value format (no YAML nesting beyond 2 levels)
- Existing 756 rules are unaffected
