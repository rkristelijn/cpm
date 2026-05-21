# Contributing

## For AI agents (Claude, Gemini, Kiro, Amazon Q, Copilot)

You are working on **cpm** — a quality layer between git and code.

### Build & run

```bash
make build
./cpm help
./cpm scan .
./cpm maturity
```

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

- Simple C++ (C++17, no boost, no template magic)
- Shell scripts: bash, `set -o errexit/nounset/pipefail`
- Conventional commits: `type(scope): description`
- No references to private paths (check `.config/.pii`)
- Comments explain WHY, not WHAT
- Use `make` targets when available

### Process (Way of Working)

See [PROCESS.md](PROCESS.md) for the full workflow.

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

- Don't reference `~/git/lab/` or work-related paths
- Don't add heavy dependencies (zero-dep philosophy)
- Don't use `system()` in scan (too slow) — use file I/O
- Don't break the 0.5s scan target for 100+ repos
