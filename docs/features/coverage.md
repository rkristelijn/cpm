# cpm coverage

Build with coverage instrumentation and report line coverage.

## Usage

```bash
cpm coverage
```

## Output

```text
  Total: 84.3% (45 files)
```

## How it works

1. Compiles with `--coverage` flag (gcov)
2. Runs unit tests
3. Reports per-file and total line coverage

## See also

- `cpm score` — includes coverage in maturity calculation
