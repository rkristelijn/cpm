# cpm format

Auto-format all source files.

## Usage

```bash
cpm format
```

## What it runs

- C/C++: `clang-format -i` (uses `.clang-format` or Google style)
- YAML: `yamllint` (check only)
- Markdown: `rumdl` (check only)
- Shell: `shfmt -w -i 2`

## See also

- `cpm check --fast` — format check without modifying files
