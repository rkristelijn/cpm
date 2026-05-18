# Configuration (cpm.toml)

All cpm settings live in a single `cpm.toml` file in your project root.

## Usage

```bash
cpm get              # show all config
cpm get project.name # show specific key
cpm set checks.code-cpp-syntax-format false   # disable a check
```

## File structure

```toml
[project]
name = "my-project"
version = "0.1.0"
lang = "cpp"           # cpp | c | typescript | python | rust
build = "make"         # make | cmake
config-dir = ".config" # where tool configs live

[tools]
llvm = "19"
cppcheck = "2.13"
gitleaks = "8.18.2"
# ... pinned tool versions

[checks]
code-cpp-syntax-format = true
code-generic-secrets-scan = true
code-cpp-complexity-measure = true

[checks.code-cpp-complexity-measure]
threshold = 10

[checks.code-cpp-comment-measure]
threshold = 20

[hooks]
pre-commit = true
pre-push = true
commit-msg = false

[limits]
source-lines = 600
header-lines = 300
script-lines = 300
files-per-dir = 20

[enforcement]
level = "guide"    # learn | guide | guard | enforce
```

## Resolution order

1. Project `cpm.toml` (highest priority)
2. Global `~/.config/cpm/cpm.toml`
3. Built-in defaults

## Zero-config mode

cpm works without `cpm.toml` — it uses sensible defaults. Run `cpm init` when you want to customize.

## Related

- [init.md](init.md) — generate cpm.toml
- [enforcement-levels.md](enforcement-levels.md) — enforcement settings
- [check.md](check.md) — check configuration
