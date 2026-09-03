---
summary: Add `cpm docs index` to generate a deterministic Markdown index of a docs directory, LLM enrichment optional and opt-in.
status: proposed
---

# ADR-171: Documentation Index Generation (`cpm docs index`)

*Date*: 2026-09-03
*Related*: [ADR-022](adr-022-native-cpp-architecture.md), [ADR-129](adr-129-unified-findings-contract.md), [ADR-168](adr-168-multi-engine-architecture.md)

## Context

Documentation directories accumulate files with no navigable overview. Finding "what lives where" means opening files one by one. cpm already curates `docs/README.md` by hand as a de-facto index (a table of features + links), but this is manual, drifts from reality, and does not scale to other repositories.

We want a command that generates a Markdown index of a documentation directory, reusable across any repo (cpm is a global binary), following the `domain-flavor-intent-method` naming convention. The named step is **`docs-markdown-index-build`**, exposed as `cpm docs index`.

Two forces are in tension:

1. **cpm's zero-runtime-dependency principle** (ADR-022): the core must work with only POSIX + RE2. No new hard dependencies.
2. **Desire for high-quality summaries** via a local LLM (Ollama), which is an external, optional, machine-specific dependency.

Resolution: the deterministic index is the core (C++, testable, CI-safe). LLM enrichment is an optional, opt-in enhancement isolated behind the existing C++→shell bridge (`run_lib_script`), with graceful fallback when Ollama is absent.

### Index location convention

Options considered:

- **Root `INDEX.md`** — rejected. Competes with `README.md`; forges auto-render `README.md`, not `INDEX.md`. Ugly and confusing.
- **`docs/INDEX.md` alongside `docs/README.md`** — rejected as default. Creates two files that both want to be "the index of docs/", the exact duplication problem we avoid elsewhere.
- **Generated block inside `docs/README.md`** — chosen as the cpm-native convention. `docs/README.md` is already cpm's index by convention and is forge-rendered. The tool writes only between explicit markers, leaving hand-written prose untouched.
- **`<DIR>/INDEX.md` as a fully-owned generated artefact** — chosen as the default for arbitrary target directories (reuse in other repos). When a target dir is not a curated `docs/` with a README, a fully-owned `INDEX.md` is predictable to regenerate and safe for `--check` drift detection.

The command therefore supports both, defaulting sensibly:

- `cpm docs index` (no arg) → updates the marker block in `./docs/README.md` if it exists.
- `cpm docs index <DIR>` → writes `<DIR>/INDEX.md` (fully owned) unless `<DIR>/README.md` exists, in which case it updates the marker block there.

Never writes to repository root.

## Decision

1. Add a new top-level command `docs` with subcommand `index`:
   `cpm docs index [DIR] [--check] [--llm] [--force]`.
2. **Iteration 1 (this ADR, deterministic only, no LLM):**
   - C++ handler `cmd_docs()` in `src/commands/cmd_docs.cpp`.
   - Walk `*.md` in DIR (non-recursive by default), extract for each file: title (frontmatter `title:` or first H1), and a one-line summary (first non-empty, non-heading paragraph, truncated).
   - Emit a Markdown table (title · path · summary) into either the marker block of `README.md` or a fully-owned `INDEX.md`, per the location convention above.
   - Generated output carries a `<!-- cpm:docs-index -->` marker and a "generated — do not edit by hand" notice.
   - `--check` mode: regenerate to memory/tmp, compare against the on-disk index, exit non-zero on drift. This is the enforcement hook.
   - Deterministic and reproducible: identical input → identical output. No network, no LLM.
3. **Iteration 2 (future, separate work, LLM enrichment):**
   - Opt-in via `--llm`. Orchestrated by a shell sidecar `lib/shell/docs-index-llm.sh` invoked through `run_lib_script` (SEC-043-hardened arg passing).
   - Sidecar performs scaffolding checks with graceful fallback: Ollama installed? daemon reachable? hardware-appropriate model selected (quick RAM probe, chosen only from `ollama list`)? If any check fails → fall back to the deterministic summary, exit 0 (never an error).
   - Summaries cached (keyed on file hash, e.g. `.cpm/docs-index-cache.jsonl`) so reruns only summarise changed files.
   - Execution model (sequential / parallel / throttled-background) is **OPEN** — to be decided at iteration 2. Iteration 1 is a simple sequential directory walk.
4. **Pre-commit integration (opt-in):**
   - Extend global hooks: `cpm hook --global --enable docs-index`.
   - Hook default runs `cpm docs index --check` (deterministic, fast, CI-safe). No LLM in the hook default.
   - Opt-in force via `--llm` / `CPM_DOCS_INDEX_LLM=1` rebuilds the index with summaries before commit ("force heredoc, forced update index").

## Enforcement

| What | How | Automation |
|------|-----|-----------|
| Index stays in sync with docs directory | `cpm docs index --check` regenerates and diffs against on-disk index; non-zero exit on drift | Pre-commit hook (`docs-index`, opt-in) + CI step |
| Generated content is not hand-edited | Content lives between `<!-- cpm:docs-index -->` markers with a "do not edit" notice; `--check` detects manual edits as drift | Same `--check` diff |
| LLM never becomes a hard dependency | Sidecar probes for Ollama and falls back to deterministic summary, exit 0 | `docs-index-llm.sh` scaffolding checks; deterministic path has zero external deps |
| Command naming follows convention | Step name `docs-markdown-index-build` matches `domain-flavor-intent-method` | Greppable step name; convention check |
| Never writes repository root | Target is a directory arg or `./docs`; root is explicitly excluded | Unit test asserting refusal to write `./INDEX.md` at repo root |

## Consequences

### Positive

- Deterministic core is testable with doctest and safe in CI (reproducible, no network).
- Reusable across any repo via `cpm docs index <DIR>` since cpm is a global binary.
- Zero-dependency principle preserved: LLM is isolated, opt-in, with graceful fallback.
- Uses established cpm patterns (thin dispatch, `run_lib_script`, findings/hook infra, ADR-driven).
- `docs/README.md` marker-block approach keeps forge-native rendering and avoids file duplication.

### Negative

- Adds a new top-level command, touching `main.cpp`, `commands.h`, `usage()`, a new `cmd_docs.cpp`, the Makefile source list, and tests.
- Two index-writing modes (marker block vs. fully-owned file) add branching to detect and handle.
- LLM enrichment (iteration 2) introduces machine-specific behaviour that must be carefully kept out of deterministic/CI paths.

## References

- @see ADR-022 (native C++ architecture, zero runtime deps)
- @see ADR-129 (unified findings contract)
- @see ADR-168 (multi-engine architecture)
- @see `src/main.cpp` `run_lib_script()` — C++→shell bridge pattern (SEC-043 hardened)
- @see `docs/conventions.md` — `domain-flavor-intent-method` naming
