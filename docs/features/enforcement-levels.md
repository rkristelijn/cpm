# Enforcement Levels

Control how strictly cpm blocks your workflow. Start gentle, grow strict when ready.

## Levels

| Level | Behavior | When to use |
|-------|----------|-------------|
| `learn` | Show tips after commit (non-blocking) | Getting started, exploring |
| `guide` | Show warnings before push (non-blocking) | Day-to-day development |
| `guard` | Block push on errors, warn on rest | Team projects |
| `enforce` | Block commit on errors + warnings | Production-critical code |

## Configuration

```toml
# cpm.toml
[enforcement]
level = "guide"
```

## What each level does

### learn

```text
$ git commit -m "add feature"
  [cpm] tip: consider adding unit tests for new code
  [cpm] tip: complexity of parse() is 12 (threshold: 10)
```

Non-blocking. Shows tips after the fact.

### guide

```text
$ git push
  [cpm] warning: 2 functions exceed complexity threshold
  [cpm] warning: no tests for new module
  Push continues...
```

Non-blocking. Warns before push so you're aware.

### guard

```text
$ git push
  [cpm] error: secret detected in config.cpp
  [cpm] warning: complexity threshold exceeded
  Push blocked (1 error). Fix errors to push.
```

Blocks on errors. Warnings are shown but don't block.

### enforce

```text
$ git commit -m "add feature"
  [cpm] error: secret detected in config.cpp
  [cpm] error: complexity threshold exceeded (was warning, now error)
  Commit blocked. Fix all issues to commit.
```

Everything blocks. Warnings become errors.

## Maturity interaction

Enforcement level works together with maturity level:

```toml
[enforcement]
level = "guard"

[maturity]
target = 2    # only enforce level 1-2 checks
```

A level 3 check won't block a project targeting level 2.

## Related

- [maturity.md](maturity.md) — maturity levels
- [hooks.md](hooks.md) — where enforcement runs
- [check.md](check.md) — what gets checked
