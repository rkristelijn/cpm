# hook-no-debug

## What it catches

Debug statements in staged code:

- **JavaScript/TypeScript**: `console.log`, `console.debug`, `debugger`
- **Ruby**: `binding.pry`, `byebug`, `pp(`
- **Python**: `pdb.set_trace`, `breakpoint()`
- **PHP**: `var_dump(`, `dd(`
- **Java**: `System.out.println`

## Why it matters

Debug statements in production leak internal state, slow down execution, and look unprofessional. A `debugger` statement will freeze the browser. `console.log` with sensitive data can expose secrets in browser dev tools. `var_dump` and `dd()` will break HTTP responses. `System.out.println` bypasses structured logging. Test files are excluded from this check.

## Examples

```javascript
// Bad
console.log("user data:", userData);
debugger;

// Good
logger.debug("user data:", userData);  // proper logger with levels
```

```php
// Bad
var_dump($user);
dd($request->all());

// Good
Log::debug('user', ['id' => $user->id]);
```

```java
// Bad
System.out.println("debug: " + value);

// Good
logger.debug("value: {}", value);
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
