# ADR-145: Gradual native migration via `cpm migrate`

## Status

Proposed

## Context

Node.js 26 makes 30+ npm packages redundant by providing native alternatives (Temporal, fetch, structuredClone, Object.groupBy, etc.). However, replacing library calls with native equivalents requires code changes that can't be done in one big bang — especially in large codebases.

Developers need a guided, incremental migration path that:

- Shows what can be replaced and the expected savings
- Applies safe replacements automatically
- Tracks progress over time
- Doesn't break anything

## Decision

Add a `cpm migrate` command that provides guided, incremental migration from library dependencies to native platform APIs.

## Design

### Command interface

```bash
cpm migrate                  # Show migration report (what can be replaced)
cpm migrate --apply          # Apply safe auto-fixes only
cpm migrate --plan           # Generate migration plan (ordered by impact)
cpm migrate --progress       # Show progress since first run
```

### How it works

1. **Detect target runtime** — read `.nvmrc`, `wrangler.toml`, `vercel.json`, `package.json` engines
2. **Scan dependencies** — cross-reference installed packages against the native replacement table
3. **Scan usage** — find actual call sites (not just imports) to determine migration effort
4. **Categorize** each finding:
   - 🟢 **Auto-fixable** — 1:1 replacement, safe to apply (`_.isArray` → `Array.isArray`)
   - 🟡 **Semi-auto** — needs minor refactor but pattern is clear (`_.get(obj, 'a.b')` → `obj?.a?.b`)
   - 🔴 **Manual** — complex usage, needs human review (`moment().add(3, 'days').format('YYYY-MM-DD')`)
5. **Apply** — with `--apply`, rewrite 🟢 patterns and generate TODO comments for 🟡
6. **Track** — store progress in `.cpm/migrate.jsonl` for trend reporting

### Migration phases

```text
Phase 1: Drop-in replacements (auto)
  _.isArray → Array.isArray
  _.keys → Object.keys
  uuid.v4() → crypto.randomUUID()

Phase 2: Pattern rewrites (semi-auto)
  _.get(obj, 'a.b.c') → obj?.a?.b?.c
  _.cloneDeep(x) → structuredClone(x)
  axios.get(url) → fetch(url).then(r => r.json())

Phase 3: API migration (manual, guided)
  moment(date).format('YYYY-MM-DD') → Temporal.PlainDate.from(date).toString()
  moment.duration(ms) → Temporal.Duration.from({milliseconds: ms})
  date-fns/addDays → Temporal.PlainDate.add({days: n})

Phase 4: Package removal
  npm uninstall moment lodash axios uuid (once all call sites migrated)
```

### Output example

```text
cpm migrate

  Migration Report (target: Node 26)
  ═══════════════════════════════════

  Package          Calls  Auto  Semi  Manual  Savings
  ─────────────────────────────────────────────────────
  lodash            47    31     12     4      -70KB
  moment            23     0      8    15     -300KB
  axios             12     0     12     0      -30KB
  uuid               3     3      0     0       -9KB
  ─────────────────────────────────────────────────────
  Total             85    34     32    19     -409KB

  Run: cpm migrate --apply    (fixes 34 safe replacements)
  Run: cpm migrate --plan     (generates TODO for 32 semi-auto)
```

### Integration with existing checks

- `check-native-alternatives.sh` → detection engine (already built)
- `check-native-compat.sh` → validates replacements work on target runtime
- `check-obsolete-deps.sh` → flags packages with 0 remaining call sites
- `docs/research/node-26-native-replacements.md` → reference data

### Progress tracking

```jsonl
{"date":"2026-05-25","total":85,"auto_fixed":0,"semi_done":0,"manual_done":0,"packages_removed":0}
{"date":"2026-05-26","total":85,"auto_fixed":34,"semi_done":5,"manual_done":0,"packages_removed":1}
{"date":"2026-06-01","total":85,"auto_fixed":34,"semi_done":32,"manual_done":12,"packages_removed":3}
```

## Consequences

- Developers get a clear, measurable path from "heavy deps" to "native-first"
- Migration happens incrementally alongside normal feature work
- cpm can report migration progress in `cpm score` (bonus points for fewer deps)
- The replacement tables serve as living documentation of native capabilities

## Implementation order

1. Wire `cpm migrate` command (shell script calling existing checks)
2. Add call-site counting (grep-based, per package)
3. Add `--apply` using existing `check-native-alternatives.sh --fix`
4. Add progress tracking (`.cpm/migrate.jsonl`)
5. Add `--plan` (generates inline TODO comments)

## Enforcement

- `check-native-alternatives.sh` runs in CI via `cpm check`; warnings on replaceable patterns
- `check-native-compat.sh` errors when APIs exceed target Node version
- `cpm score` deducts points for heavy/obsolete deps (via `check-obsolete-deps.sh`)
- `.cpm/migrate.jsonl` must be present and updated when migration is active
- `--plan` generates TODO comments; reviewers verify migration plan exists for flagged packages
