# cpm score

Show maturity score (0-100) with badge and trend tracking.

## Usage

```bash
cpm score
```

## Output

```
  cpm — maturity score

  Score: 97/100 (excellent)
  Level: 5 (excellent)
  Errors: 0 | Warnings: 1
  Trend: 3 measurements (+5 since first)

  Badge:
  ![cpm score](https://img.shields.io/badge/cpm%20score-97%25-brightgreen)
```

## Scoring

- Start at 100
- -10 per error
- -3 per warning

## Levels

| Score | Level |
|-------|-------|
| 95-100 | 5 (excellent) |
| 85-94 | 4 (optimized) |
| 70-84 | 3 (measured) |
| 50-69 | 2 (defined) |
| 30-49 | 1 (managed) |
| 0-29 | 0 (initial) |

## Trend

Scores are saved to `.cpm/scores.jsonl`. Run `cpm score` regularly to track improvement.
