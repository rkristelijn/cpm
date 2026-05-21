# cpm install

Install quality tools defined in `cpm.toml`.

## Usage

```bash
cpm install
```

## What it installs

Reads `[tools]` section from `cpm.toml` and installs via the platform package manager:

- macOS: `brew install`
- Linux (Debian): `apt-get install`
- Alpine: `apk add`

## Supported tools

cppcheck, cloc, shellcheck, shfmt, yamllint, gitleaks, semgrep, doxygen, rumdl, trivy, ripgrep, vale, lychee, alex (alexjs), cspell

## See also

- `cpm audit` — check if installed versions match cpm.toml
- `cpm tools` — show installed tool versions
