# Writing cpm Rules

A cpm rule is a small `.rule` file (TOML-ish `key: value`) under `rules/<area>/`.
This is the complete reference for the rule format and every engine. It is the
authoritative companion to the design/ADR docs:

- ADR-145 — pluggable rule engine (rationale)
- ADR-166 — engine extensions (file/scope/cross-file/extract engines)
- `docs/designs/rule-engine-config.md` — project config & suppression

Field names below are the ones the parser actually reads
(`src/rules/rule_engine.cpp`), so this list stays in sync with the code.

## Anatomy of a rule

```yaml
id: GO-QUAL-028                 # unique ID: <AREA>-<CATEGORY>-<NNN>
title: Opened resource never closed
category: quality              # quality | security | a11y | performance | ...
severity: warning              # error | warning | info
engine: block-absence          # see "Engines" below (default: pattern)
skip_comments: true            # strip // and /* */ before matching (optional)
skip_strings: true             # strip "..." '...' `...` before matching (optional)
target:
  extensions: .go              # space-separated file extensions
  filenames: Makefile          # space-separated exact basenames (optional)
  exclude_paths: vendor/ _test.go   # substring path excludes (optional)
  content_contains: os.        # fast pre-filter: skip files lacking this (optional)
patterns:
  - regex: ^func\b
    message: "Function opens a resource but never closes it."
fix: "Add `defer f.Close()` after a successful open."
```

Every rule needs `id`, `severity`, and `engine` (or defaults to `pattern`).
`message` may live on the rule or per-pattern; `{match}` is substituted where
supported.

## Engines

### `pattern` (default)

Flags each line matching any `patterns[].regex`.

- `exclude_names` (optional): space-separated call names. If the matched line
  also contains a call to one of them (e.g. `t(`, `$t(`), the finding is
  suppressed. Use this instead of negative lookahead — RE2 has none.

```yaml
engine: pattern
patterns:
  - regex: \beval\s*\(
    message: "Avoid eval()."
exclude_names: safeEval
```

### `absence` / `presence`

`absence` flags a file where **no** line matches the pattern (something required
is missing). `presence` flags a file where a pattern **does** appear (used with
`content_contains` as a gate).

### `file-absence` / `file-presence`

Operate on the file tree, not content. `file-absence` flags when no file matches
`target.filenames`/`target.extensions` (e.g. "project has no man page").
`file-presence` flags when such a file exists.

### `extract-duplicates`

Extracts a capture group across a file and flags values that occur more than
once (e.g. duplicate test names, duplicate headings).

```yaml
engine: extract-duplicates
extract: ^\s{0,3}#{2,6}\s+(.+?)\s*#*\s*$   # capture group 1 is the value
capture: 1                                 # capture index (default 1)
message: "Duplicate heading '{match}'."
```

### `block-absence`

Brace-scope analysis without a full parser: find the block opened by the first
pattern, count `{`/`}` to its end, and flag the block when a required inner
regex never appears inside it.

- `patterns[0].regex` — the **block-START** matcher (e.g. `\b(it|test)\s*\(`).
- `block_inner` — regex that MUST appear inside the block's braces.
- `block_trigger` (optional) — **gate**: only evaluate blocks that contain this
  regex. Turns the engine into a general "scope contains A but not B" check.
  When omitted, every matched block is evaluated (original behaviour).

Set `skip_strings: true` / `skip_comments: true` so braces inside strings or
comments don't skew the depth count.

```yaml
# "a test with no assertion"
engine: block-absence
patterns:
  - regex: (^|[^.\w])(it|test)\s*\(
    message: "Test has no assertion."
block_inner: \b(expect|assert)\s*[.(]
```

```yaml
# "a function that opens a resource but never closes it" (block_trigger gate)
engine: block-absence
patterns:
  - regex: ^func\b
    message: "Resource opened but never closed."
block_trigger: \bos\.(Open|Create|OpenFile)\s*\(
block_inner: \.Close\s*\(|defer\s
```

## Verifying a new rule

1. `make build && ./build/test_rules -ts=rules-smoke` — every `.rule` file
   parses and every regex compiles in RE2.
2. Add a unit test in `src/rules_test.cpp` (see the block-absence scenarios)
   asserting the exact findings.
3. Add a fixture + `expect` in `cpm-eval/tests/test-new-rules.sh` for an
   end-to-end check via `rule-scan`.
4. `make test-unit` — all rule tests green.

## Suppression

- Inline: `cpm:ignore <rule-id>` or `cpm:ignore <category>` on the line.
- Project: `[rules] skip = [...]` / `skip_categories` / `exclude_paths` in
  `cpm.toml`. See `docs/designs/rule-engine-config.md`.
