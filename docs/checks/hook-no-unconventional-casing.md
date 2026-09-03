# hook-no-unconventional-casing

## What it catches

Files and folders that don't follow lower-kebab-case naming, and known files with wrong casing (e.g., `readme.md` instead of `README.md`).

## Why it matters

Inconsistent naming causes confusion, breaks cross-platform builds (macOS is case-insensitive, Linux is not), and makes files harder to find. Known community conventions exist for files like `README.md`, `Makefile`, and `Dockerfile` — deviating from them breaks tooling expectations.

## Examples

```text
# Bad
MyComponent.tsx        # (unless React project)
User_Service.js
ReadMe.md              # should be README.md

# Good
my-component.tsx       # lower-kebab-case
user-service.js
README.md              # correct community convention
```

## React / Angular PascalCase

For React and Angular projects, PascalCase component files are automatically allowed:

```text
# Allowed in React/Angular projects
MyComponent.tsx        # ✓ auto-detected via package.json
UserProfile.vue        # ✓ when allow-pascal-case = true
```

Enable manually in `cpm.toml`:

```toml
[naming]
allow-pascal-case = true
```

## Override

- Global: `cpm hook --global --disable no-unconventional-casing`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-unconventional-casing = false
  ```

- One commit: `git commit --no-verify`
