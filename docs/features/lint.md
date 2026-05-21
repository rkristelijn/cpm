# cpm lint

Run all lint checks without modifying files.

## Usage

```bash
cpm lint
```

## What it runs

- C/C++: `cppcheck`, `clang-tidy`
- Shell: `shellcheck`
- YAML: `yamllint`
- Markdown: `rumdl`

## See also

- `cpm check` — full quality gate (lint + test + security)
- `cpm format` — auto-fix formatting issues
