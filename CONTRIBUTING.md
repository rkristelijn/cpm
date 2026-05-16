# Contributing

## For AI agents (Claude, Gemini, Kiro, Amazon Q, Copilot)

You are working on **cpm** — a quality layer between git and code.

### Build & run

```bash
g++ -std=c++17 -O2 -o cpm src/main.cpp src/runner.cpp src/setup.cpp src/toml.cpp src/scan.cpp
./cpm help
./cpm scan .
./cpm maturity
```

### Architecture

```
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

