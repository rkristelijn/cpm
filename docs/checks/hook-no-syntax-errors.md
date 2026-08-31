# hook-no-syntax-errors

## What it catches

Invalid JSON and YAML syntax in staged files.

## Why it matters

A single misplaced comma in JSON or wrong indentation in YAML will break configuration loading, CI pipelines, and deployments. These errors are trivial to catch pre-commit but expensive to debug in production when a config file silently fails to parse.

## Examples

```json
// Bad — trailing comma
{
  "name": "app",
  "version": "1.0",
}

// Good
{
  "name": "app",
  "version": "1.0"
}
```

## Override

- Global: `cpm hook --global --disable no-syntax-errors`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-syntax-errors = false
  ```

- One commit: `git commit --no-verify`
