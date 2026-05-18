# Maturity levels

cpm scores your project on a 0–4 maturity scale. Each level unlocks naturally as you adopt more practices.

## Usage

```bash
cpm maturity          # show current level and score
bash lib/shell/maturity.sh   # standalone maturity audit
```

## Levels

| Level | Name | What's expected |
|-------|------|-----------------|
| 0 | Initial | Nothing — just code |
| 1 | Managed | Formatting, secrets scan, hooks, tests |
| 2 | Defined | + docs, CI, complexity limits, conventional commits |
| 3 | Measured | + DORA metrics, trends, coverage gates |
| 4 | Optimized | + auto-remediation, AI-assisted review |

## Output

```text
$ cpm maturity
  Level: 2 (Defined)
  Score: 12/18

  Ready for level 3? Try:
    → cpm enable slop-detection
    → cpm enable timing
```

## Scoring

Each practice contributes points. The level is determined by total score:

| Practice | Points |
|----------|--------|
| Has cpm.toml | 1 |
| Hooks installed | 1 |
| Tests exist | 1 |
| Formatting configured | 1 |
| Secrets scanning | 1 |
| CONTRIBUTING.md | 1 |
| CI pipeline | 1 |
| Coverage > 60% | 2 |
| Conventional commits | 1 |
| ADRs documented | 1 |
| ... | ... |

## Philosophy

- Levels unlock gradually — cpm suggests the next step when you're ready
- No all-or-nothing: a level 1 project only gets level 1 checks enforced
- Based on ISO 25010 quality characteristics + DORA metrics + OpenSSF Scorecard

## Related

- [enforcement-levels.md](enforcement-levels.md) — how levels affect blocking
- [check.md](check.md) — what checks run at each level
