# Usage Modes

cpm adapts to your workflow. Use as much or as little as you want.

## Mode 1: Scan only (non-intrusive)

Zero files added to your repo. Point cpm at code and get results.

```bash
cpm scan ~/projects --depth 2
cpm score
cpm findings --learn
```

What it does:
- Reads your files (never modifies)
- Reports findings to ~/.local/share/cpm/
- No config files, no hooks, no changes to your repo

Best for: evaluating repos, auditing, one-off scans.

## Mode 2: Config only (minimal)

One file: `cpm.toml`. Optionally `.config/` for tool configs.

```bash
cpm init          # creates cpm.toml + .editorconfig + SECURITY.md
cpm check --fast  # runs checks based on cpm.toml
```

What it adds:
- `cpm.toml` — which checks to run, tool versions
- `.editorconfig` — editor-agnostic formatting
- `SECURITY.md` — vulnerability disclosure policy
- `.github/ISSUE_TEMPLATE/` — issue templates

Best for: personal projects, small teams getting started.

## Mode 3: Hooks (embedded in workflow)

cpm installs git hooks that run checks automatically.

```bash
cpm hook    # installs pre-commit + pre-push hooks
```

What it does:
- `pre-commit`: format (fast, <5s)
- `pre-push`: lint + test (blocks push on errors)
- `commit-msg`: conventional commit validation (optional)

Best for: teams that want automated quality gates.

## Mode 4: Full integration (maximum value)

All tools installed, all checks active, compliance tracking.

```bash
cpm install           # installs vale, alex, cspell, lychee, semgrep, gitleaks
cpm check --full      # runs all 58 checks
cpm score             # tracks maturity over time
cpm findings --compliance ISO27001
```

What it adds:
- External tools (installed via brew/apt, managed by cpm)
- `.cpm/scores.jsonl` — score history for trend tracking
- Full compliance mapping (ISO 27001, GDPR, CMMI, OWASP, WCAG)

Best for: teams with compliance requirements, open source projects.

## Comparison

| Aspect | Scan only | Config | Hooks | Full |
|--------|-----------|--------|-------|------|
| Files in repo | 0 | 2-5 | 2-5 | 5-10 |
| Automation | None | Manual | Git events | Git + CI |
| External tools | None | None | None | 10+ |
| Compliance | Report only | Report | Enforce | Enforce + audit |
| Setup time | 0 | 1 min | 2 min | 5 min |

## Removing cpm

```bash
cpm unhook              # remove git hooks
rm cpm.toml .editorconfig SECURITY.md
rm -rf .github/ISSUE_TEMPLATE .github/pull_request_template.md
rm -rf .cpm
```

cpm never modifies your source code. All cpm artifacts are config files that can be deleted without affecting your project.
