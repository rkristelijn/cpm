# cpm init

Bootstrap a new project with sensible defaults.

## Usage

```bash
cd my-project
cpm init
```

## What it does

Creates a `cpm.toml` in the current directory with:

- Project name (derived from directory name)
- Language detection (defaults to `cpp`)
- Build system (`make`)
- Tool versions (pinned)
- Default checks (format, lint, complexity, secrets)
- Hook configuration (pre-commit + pre-push enabled)

## Generated cpm.toml

```toml
[project]
name = "my-project"
version = "0.1.0"
lang = "cpp"
build = "make"
config-dir = ".config"

[tools]
llvm = "19"
cppcheck = "2.13"
cloc = "2.02"
shellcheck = "0.10.0"
shfmt = "3.7.0"
yamllint = "1.33.0"
rumdl = "0.1.73"
doxygen = "1.16.1"
semgrep = "1.56.0"
gitleaks = "8.18.2"
pmccabe = "2.8"

[checks]
code-cpp-syntax-format = true
code-cpp-syntax-lint = true
code-cpp-complexity-measure = true
code-cpp-comment-measure = true
code-generic-vulnerability-scan = true
code-generic-secrets-scan = true
# ... more checks

[hooks]
pre-commit = true
pre-push = true
commit-msg = false
```

## Next steps

```bash
cpm install       # install pinned tools
cpm hook          # install git hooks
cpm check --fast  # verify everything works
```

## Notes

- Fails if `cpm.toml` already exists (won't overwrite)
- No files are committed to git — cpm works as a global binary
- Edit `cpm.toml` to disable checks you don't need
