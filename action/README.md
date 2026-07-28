# cpm — quality gate action

Run [cpm](https://github.com/rkristelijn/cpm) quality checks on any repo. Zero config, one step, actionable findings as PR annotations.

## Quick start

```yaml
# .github/workflows/quality.yml
on: [push, pull_request]
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: rkristelijn/cpm@v1
```

That's it. cpm auto-detects your language and runs 58+ quality checks.

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `level` | `guide` | Enforcement level: `learn` \| `guide` \| `guard` \| `enforce` |
| `tier` | `default` | Check tier: `fast` (format+build) \| `default` (+lint+test) \| `full` (+coverage+sast) |
| `version` | `latest` | cpm version to install |
| `rules` | `true` | Run rule-scan engine |
| `annotations` | `true` | Emit PR annotations for findings |

## Outputs

| Output | Description |
|--------|-------------|
| `score` | Maturity score (0–100) |
| `findings` | Number of findings |
| `exit-code` | Exit code of cpm check (0 = pass) |

## Examples

### Guard mode (block on errors)

```yaml
- uses: rkristelijn/cpm@v1
  with:
    level: guard
    tier: full
```

### Use score in subsequent steps

```yaml
- uses: rkristelijn/cpm@v1
  id: cpm
- run: echo "Score is ${{ steps.cpm.outputs.score }}/100"
```

### Pin version

```yaml
- uses: rkristelijn/cpm@v1
  with:
    version: '0.7.0'
```

## What it does

1. **Installs cpm** — downloads the binary (fast, no runtime deps)
2. **Runs `cpm check`** — 58+ checks across security, quality, docs, supply chain
3. **Runs `cpm rule-scan`** — custom YAML rule engine with regex/AST patterns
4. **Annotates PR** — findings appear inline on changed files
5. **Writes summary** — score + findings in the job summary

## Enforcement levels

| Level | Blocks on | Best for |
|-------|-----------|----------|
| `learn` | Nothing | Getting started |
| `guide` | Nothing | Day-to-day |
| `guard` | Errors only | Team projects |
| `enforce` | Errors + warnings | Production |

## Supported languages

C++, C#, Dart/Flutter, Go, Java, JavaScript/TypeScript, PHP, Python, Ruby, Rust, Terraform, and more.

## License

MIT
