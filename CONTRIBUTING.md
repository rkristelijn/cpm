# Contributing

## Getting started

### Prerequisites

C++20 compiler (g++ or clang++) and `make` are required. The following
tools are used by cpm's quality checks — install them to get full
coverage locally:

```bash
# Required: build
brew install re2            # regex engine (macOS)
# sudo apt-get install -y libre2-dev  # (Ubuntu/Debian)

# Required: quality checks
brew install cppcheck shellcheck shfmt yamllint
npm install -g cspell@10 @alexjs/cli@11

# Optional: docs + coverage
brew install vale lychee
pip install gcovr
```

### Build & run

```bash
make build        # compile cpm binary
make test         # run unit tests
./cpm help        # show available commands
./cpm check       # run quality checks on this repo
```

### Install git hooks

cpm uses three git hooks to prevent quality regressions. Set them up
after cloning:

```bash
# Option A: use cpm's built-in hook installer
cpm hook

# Option B: use git's core.hooksPath (no copy needed)
git config core.hooksPath .githooks
```

| Hook | Runs | What it checks |
|------|------|----------------|
| `pre-commit` | `cpm check --fast` | Format + build (<5s) |
| `pre-push` | `cpm check` | + lint + test + rules (<60s) |
| `commit-msg` | conventional commits | `type(scope): description` |

The CI pipeline runs `cpm check --full` (Tier 3: coverage + sast +
mutation) as a blocking quality gate. Nothing merges if it fails.

### Quality tiers

| Tier | Command | When | Time |
|------|---------|------|------|
| 1 | `cpm check --fast` | pre-commit | <5s |
| 2 | `cpm check` | pre-push | <60s |
| 3 | `cpm check --full` | CI pipeline | ~2min |

### CI pipeline flags

The CI workflow (`.github/workflows/ci.yml`) reads directives from the **head
commit message** so you can run individual stages in isolation while
iterating — useful when only one platform or step is failing and you don't
want to wait for the full matrix.

| Directive | Effect |
|-----------|--------|
| `[ci only-win]` | Run only the Windows build; skip Linux/macOS builds |
| `[ci no-win]` | Skip the Windows build |
| `[ci no-lint]` | Skip the `lint-scripts` job |

Put the token anywhere in the commit subject or body, e.g.:

```bash
git commit -m "fix: windows mkdir path

[ci only-win]"
```

Notes:

- Tokens are advisory on PRs; pushes to `main` always run the full matrix.
- Combine tokens freely (e.g. `[ci no-win] [ci no-lint]`).
- Implemented by the `flags` job, which parses `git log -1` and exposes
  `only_win` / `no_win` / `no_lint` outputs consumed by later jobs.

## For AI agents (Claude, Gemini, Kiro, Amazon Q, Copilot)

You are working on **cpm** — a quality layer between git and code.

### Architecture

```text
src/
├── main.cpp       ← CLI dispatch (commands → functions)
├── scan.cpp/.h    ← polyrepo scanner (fast, file-based)
├── runner.cpp/.h  ← check runner (shell out to scripts)
├── setup.cpp/.h   ← tool installation
├── toml.cpp/.h    ← cpm.toml parser

lib/shell/         ← bash framework (sourced by checks)
├── init.sh        ← single entry point for scripts
├── findings.sh    ← JSONL findings database
├── ui.sh          ← TUI output (colors, spinners, progress)
├── timer.sh       ← timing + trend detection
├── run.sh         ← wrapper (timing + tee)
└── maturity.sh    ← maturity level audit

checks/
├── universal/     ← any repo (26 checks)
├── cpp/           ← C++ repos (11 checks)
└── typescript/    ← TS/JS repos (planned)
```

### Rules

- Simple C++ (C++20, no boost, no template magic)
- Shell scripts: bash, `set -o errexit/nounset/pipefail`
- Conventional commits: `type(scope): description`
- No references to private paths (check `.config/.pii`)
- Comments explain WHY, not WHAT
- Use `make` targets when available

### Process (Way of Working)

See the process section below for the full workflow.

**Process-guided development** — enforce with `cpm phase on`:

```bash
# Phase 1: IDEE — create issue
cpm issue "fix: my bugfix"

# Phase 2: BRANCH — create branch from issue
cpm issue branch my-bugfix

# Phase 3: CODE — write code + tests
# (blocked on main if phase enforcement is ON)

# Phase 4: CHECK — validate
cpm check --fast

# Phase 5: PUSH — commit, push, PR
git add -A
git commit -m "fix(scope): description

Closes: my-bugfix"
git push -u origin fix/my-bugfix
make pr-create
```

**Phase enforcement:**

```bash
cpm phase on      # activate (writes .cpm-phase)
cpm phase         # show current phase + next action
cpm phase off     # deactivate
```

When active, pre-commit hook blocks:

- Code on main → "create issue + branch first"
- Code without tests → warning

**Exit criteria per phase:**

| Phase | Exit when |
|-------|-----------|
| 1. Idee | Issue exists in docs/issues/open/ |
| 2. Branch | Not on main |
| 3. Code | Staged code + tests |
| 4. Check | `cpm check --fast` passes |
| 5. Push | PR created, pipeline green, merged via `make pr-merge` |

**After merge:** `cpm issue close <slug>`

**Rules:**

- No direct merge to main (always via PR + pipeline)
- No `git checkout main` while phase is active (finish work first)
- No `git push main` (use `make pr-create`)

**Enforced at maturity level 3:**

- No code commits on main (use feature branch)
- feat/fix commits must reference an issue (scope or `closes #N`)
- Code changes require tests in the same commit
- All checks pass before push

### Key ADRs

- ADR-013: Product positioning (layer between git and code)
- ADR-014: Findings database (JSONL format)
- ADR-015: TypeScript plugin
- ADR-016: Traceability matrix
- ADR-017: Polyrepo scan

### Testing

```bash
./cpm scan . --depth 1     # test scan on self
./cpm maturity             # should be level 3
bash lib/shell/maturity.sh # test maturity script
```

### Don't

- Don't reference `~/repos/` or work-related paths
- Don't add heavy dependencies (zero-dep philosophy)
- Don't use `system()` in scan (too slow) — use file I/O
- Don't break the 0.5s scan target for 100+ repos
