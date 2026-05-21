# cpm bump

Bump the project version in `cpm.toml`.

## Usage

```bash
cpm bump patch   # 0.1.0 → 0.1.1
cpm bump minor   # 0.1.0 → 0.2.0
cpm bump major   # 0.1.0 → 1.0.0
```

## What it does

1. Reads current version from `cpm.toml`
2. Increments the specified part (semver)
3. Writes new version to `cpm.toml`

## See also

- `cpm version` — show current version
