# hook-no-debug

## What it catches

Debug statements in staged code: `console.log`, `console.debug`, `debugger`, `binding.pry`, `byebug`, `pdb.set_trace`, `breakpoint()`.

## Why it matters

Debug statements in production leak internal state, slow down execution, and look unprofessional. A `debugger` statement will freeze the browser. `console.log` with sensitive data can expose secrets in browser dev tools. Test files are excluded from this check.

## Examples

```javascript
// Bad
console.log("user data:", userData);
debugger;

// Good
logger.debug("user data:", userData);  // proper logger with levels
```

## Override

- Global: `cpm hook --global --disable no-debug`
- Per-repo: add to cpm.toml:

  ```toml
  [hooks.global]
  no-debug = false
  ```

- Inline: add `cpm:ignore` comment on the line
- One commit: `git commit --no-verify`
