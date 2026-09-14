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

## Note: shfmt normalizes structure, not just whitespace

`shfmt` is an AST-based formatter: it parses each script and re-prints it in a
canonical form. This means `cpm format` may change more than indentation, even
though the behavior is preserved. Expect normalizations such as:

- backslash line-continuations (`cmd \`) rewritten as trailing operators
  (`cmd |`, `cmd &&`) where equivalent;
- one-line `if`/`case` branches expanded to multi-line;
- parameter expansions canonicalized, e.g. `${v/.}` → `${v/./}` (both delete
  the first `.`; the second is shfmt's explicit form).

These are semantically equivalent reprints, not functional changes, and cannot
be disabled per-line — they are inherent to how shfmt works. If a diff looks
functional, verify with `git diff -w` (ignores whitespace) and a quick behavior
check; the change is expected to be behavior-preserving.

## See also

- `cpm check --fast` — format check without modifying files
