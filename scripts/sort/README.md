# sort toolkit

Zero-dependency sort tooling for reusable ordering conventions.

## Commands

1. `bash scripts/sort/sortkit.sh check --mode cpm-toml --file cpm.toml`
2. `bash scripts/sort/sortkit.sh fix --mode cpm-toml --file cpm.toml`
3. `bash scripts/sort/sortkit.sh check --mode ts-imports --file src/foo.ts`
4. `bash scripts/sort/sortkit.sh fix --mode ts-imports --file src/foo.ts`
5. `bash scripts/sort/sortkit.sh fix --mode lines --file list.txt --dedup`

## Grouped import behavior

Order:

1. third-party imports
2. alias/library imports (default prefixes: `@/`, `~/`, `src/`)
3. relative imports (`./`, `../`)

A blank line is inserted between non-empty groups.

## Wrapper scripts

1. `scripts/sort/check-cpm-toml-order.sh`
2. `scripts/sort/fix-cpm-toml-order.sh`
3. `scripts/sort/check-ts-import-order.sh`
4. `scripts/sort/fix-ts-import-order.sh`
