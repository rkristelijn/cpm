# ADR-159: Reusable Canonical Sort Toolkit (cpm.toml + TS imports + lists)

## Status

Proposed (2026-07-25)

## Context

We want consistent ordering with as few dependencies as possible.

Goals:

1. Stable diffs and easier reviews.
2. Reusable detect/fix logic for multiple commands and checks.
3. Zero or near-zero external dependencies.
4. No functional regressions.
5. Group-aware sorting (for example import groups with blank lines).

Important TOML caveat:

- TOML does not require keys/tables to be sorted.
- Naive global sorting can break valid TOML semantics in some cases.
- Examples that can break with naive sorting:
  - Parent/child table ordering with implicit table creation.
  - Dotted keys mixed with explicit tables.
  - Array-of-table blocks where order is meaningful.

For cpm.toml specifically, the schema used by cpm is constrained and predictable:

- Top-level tables such as project, tools, checks, hooks, runner, limits, process, issues.
- Nested check config tables under checks.<name>.
- No need to support generic TOML transformations across arbitrary files.

For TypeScript imports, grouping semantics are explicit and desired:

1. Third-party imports first.
2. Internal alias/library imports second.
3. Relative local imports last.
4. One blank line between non-empty groups.

## Decision

Adopt a reusable sort toolkit with specialized modes.

Modes in scope (v1):

1. cpm-toml (schema-aware, safe ordering)
2. ts-imports (group-aware import sorting)
3. lines (generic sorted blocks with optional dedup)

Scope details:

1. Canonicalize table order using a fixed allowlist for known top-level sections.
2. Sort keys alphabetically inside selected tables (tools, checks, limits).
3. Keep functional sections stable where readability matters (project, hooks, runner, process, issues).
4. Keep nested check subtables grouped after checks, sorted by check name.
5. Optional dedup mode:
   - Detect duplicate keys in same table.
   - Default behavior: fail detection and print duplicates.
   - Fix mode with explicit flag may keep last value and remove earlier duplicates.

Non-goals:

1. Generic TOML sorting for all TOML documents.
2. Reordering array-of-table entries.
3. Rewriting comments with perfect round-trip fidelity in v1.

## Why this is safe

1. cpm runtime reads cpm.toml by section/key; semantic behavior does not depend on key order.
2. Canonicalization is constrained to cpm schema, avoiding generic TOML edge cases.
3. Import sorting is constrained to import blocks only, preserving runtime semantics.
4. Detect mode runs before fix mode so users can review changes.

## Dependency strategy

Primary strategy: zero external dependencies.

- Implement canonicalization using cpm codebase (native parser/writer path) or a small repo-local script.
- Do not require taplo, Python TOML packages, or Node TOML packages in the default path.

Optional strategy:

- External formatter can be supported as an opt-in fallback for contributors who already have it installed.
- Not required for CI gate.

## Proposed interface

1. Detect:
   - scripts/sort/sortkit.sh check --mode cpm-toml --file cpm.toml
   - scripts/sort/sortkit.sh check --mode ts-imports --file src/file.ts
   - exits non-zero when file is not canonical.
2. Fix:
   - scripts/sort/sortkit.sh fix --mode cpm-toml --file cpm.toml
   - scripts/sort/sortkit.sh fix --mode ts-imports --file src/file.ts
3. Dedup option:
   - scripts/sort/sortkit.sh fix --mode cpm-toml --file cpm.toml --dedup
   - scripts/sort/sortkit.sh fix --mode lines --file list.txt --dedup

Shell wrappers may mirror this:

- scripts/sort/check-cpm-toml-order.sh
- scripts/sort/fix-cpm-toml-order.sh
- scripts/sort/check-ts-import-order.sh
- scripts/sort/fix-ts-import-order.sh

## Reuse points

The same toolkit can be reused in:

1. Pre-commit hook validation.
2. cpm check Tier 2 lint stage.
3. cpm init post-generation normalization.
4. cpm set / cpm bump post-write normalization.
5. CI enforcement in this repository and downstream repos.
6. Language checks for TypeScript import hygiene.

## Sorting opportunities matrix

Sorting applies in more places than configuration files. This matrix defines where sorting is useful and what cpm should support.

1. Source code readability and structure
   - Imports: group-aware ordering (third-party, internal alias, relative) with blank lines between groups.
   - Class/function organization: optional future checks for public-to-private or stable method ordering.
   - Object keys/enums/config maps: deterministic ordering to reduce merge conflicts and spot duplicates.

2. In-memory data structures and algorithms
   - Arrays/lists: deterministic sort before binary-search-like operations.
   - Object lists by attribute: stable sort by key fields (id, date, name) for deterministic output.
   - Priority-like queues: explicit ordering semantics when processing findings and reports.

3. Database and query layers
   - Query output ordering (for example ORDER BY) to prevent non-deterministic report diffs.
   - Index-aware design where sorting/search throughput matters.
   - Keep DB sorting server-side where possible instead of sorting large results in app code.

4. End-user UX and reporting
   - Sortable tables/lists in generated reports.
   - Relevance sorting for findings and scan output.
   - Stable default order in CLI summaries to improve scanability.

Repository mapping (initial scope):

1. Implemented in this ADR scope
   - cpm.toml canonical sorting.
   - TypeScript import grouping and member sorting.
   - Generic line sorting with optional dedup.

2. Planned follow-ups
   - Stable finding sort strategies in report output.
   - Optional class/member order checks.
   - Optional sort checks for JSON/YAML key order where semantically safe.

## Consequences

Positive:

1. Lower review noise and merge conflicts in cpm.toml edits.
2. No mandatory extra toolchain.
3. Explicit and safe behavior for duplicates.

Trade-offs:

1. v1 may not preserve every comment position perfectly.
2. Implementation is schema-specific, not a universal TOML pretty-printer.

## Alternatives considered

1. Require external formatter (for example Taplo):
   - Rejected for default path due to dependency overhead.
2. Generic text sort (grep/sed/awk without TOML awareness):
   - Rejected because it can break semantics.
3. Do nothing:
   - Rejected because inconsistent ordering keeps creating noisy diffs.

## Rollout plan

1. Add detect script with non-destructive validation.
2. Add fix script with explicit apply mode.
3. Add optional dedup flag behind explicit user intent.
4. Add ts-import mode with grouped sorting and blank-line separators.
5. Wire detect into checks as warning first, then enforce after stabilization.

## Acceptance criteria

1. Running detect twice without changes is stable.
2. Running fix twice yields byte-identical output (idempotent).
3. Existing cpm commands parse canonicalized cpm.toml unchanged.
4. Duplicate-key behavior is explicit and tested.
