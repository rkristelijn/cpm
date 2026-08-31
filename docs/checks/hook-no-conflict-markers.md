# hook-no-conflict-markers

## What it catches

Unresolved merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) in staged files.

## Why it matters

Conflict markers in committed code will break compilation, crash parsers, and produce runtime errors. They indicate an incomplete merge that was accidentally staged. This is one of the most common and embarrassing mistakes in collaborative development.

## Examples

```text
# Bad
<<<<<<< HEAD
const api = "/v2/users";
=======
const api = "/v1/users";
>>>>>>> feature-branch

# Good
const api = "/v2/users";
```

## Override

- Global: `cpm hook --global --disable no-conflict-markers`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-conflict-markers = false
  ```

- One commit: `git commit --no-verify`
