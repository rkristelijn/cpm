# cpm commit

Interactive conventional commit helper. Guides you through creating a properly formatted commit message.

## Usage

```bash
cpm commit
```

## Flow

```text
$ cpm commit

  Staged (3 files):  [ctrl-c to abort]
    src/parser.cpp
    src/parser.h
    src/parser_test.cpp

  f)fix a)feat r)refactor d)docs
  t)test b)build c)ci p)perf s)style x)chore
  Type [f]: a
  Scope (enter=none): parser
  Imperative: add X, fix Y, remove Z
  Desc: add TOML array support
  Breaking? [y/N]: n

  → feat(parser): add TOML array support
  Commit? [Y/n]: y
```

## Features

- Shows staged files before committing
- Warns if code changed without tests or docs staged
- Enforces conventional commit format
- Supports breaking change indicator (`!`)
- Abortable at any point with ctrl-c

## Commit types

| Key | Type | Use for |
|-----|------|---------|
| f | fix | Bug fixes |
| a | feat | New features |
| r | refactor | Code restructuring |
| d | docs | Documentation |
| t | test | Adding tests |
| b | build | Build system |
| c | ci | CI/CD changes |
| p | perf | Performance |
| s | style | Formatting |
| x | chore | Maintenance |

## Hook validation

When hooks are installed (`cpm hook`), the commit-msg hook validates that all commits follow the conventional format — even commits made without `cpm commit`.

```toml
# cpm.toml
[hooks]
commit-msg = true   # enable validation hook
```

## Related

- [hooks.md](hooks.md) — install commit-msg validation hook
- [enforcement-levels.md](enforcement-levels.md) — control blocking behavior
