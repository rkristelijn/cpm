# R-025: Supply Chain Attack Detection Research

*Date*: 2026-08-27 · *Status*: Implemented

## Summary

Software supply chain attacks compromise applications by poisoning upstream dependencies, build systems, CI/CD pipelines, and package registries — rather than attacking the application itself. The attack surface has exploded: npm, PyPI, crates.io, and Maven Central collectively serve billions of downloads per week, and a single compromised package can cascade to thousands of downstream projects.

Static detection matters because these attacks embed themselves in files developers already trust — `package.json`, `setup.py`, `Dockerfile`, `.github/workflows/*.yml`, `Makefile`. By the time a dynamic scanner catches execution, the payload has already run. cpm detects supply chain attack patterns at the file level, before any code executes, using grep-compatible regex rules on package manifests, build configs, CI pipelines, and lock files.

This research catalogs 70 attack vectors across 15 categories, each mapped to a `.rule` file in `rules/supply-chain/`. The checks range from high-confidence indicators of compromise (encoded payload execution, reverse shells) to awareness-level best-practice gaps (missing lockfile hashes, verbose permissions).

### Severity distribution

| Severity | Count | Meaning |
|----------|-------|---------|
| **error** | 28 | Immediate security risk — likely malicious or dangerous |
| **warning** | 27 | Suspicious pattern — needs investigation |
| **info** | 15 | Awareness — audit trail, best practice |

### Overlap with existing cpm checks

| Existing check | Overlap | What supply chain rules add |
|----------------|---------|----------------------------|
| `check-dangerous-shell.sh` | SCA-058 (curl\|bash) | Broader file coverage (Dockerfile, YAML, Makefile) |
| `check-ci-quality.sh` | Unpinned actions, injection-risk | SCA-013–017 (env injection, workflow_run, permissions) |
| `check-secrets-fast.sh` | API keys/tokens | SCA-050–053 (config-file-specific credentials) |
| `check-version-pins.sh` | SHA pinning | SCA-055 (reusable workflow pinning) |

---

## Attack Taxonomy

All 70 checks organized by category:

| ID | Category | Attack Vector | Severity | Detection Method |
|----|----------|--------------|----------|-----------------|
| SCA-001 | Package Manifest | npm postinstall with network call | error | Regex: lifecycle script contains curl/wget/node -e |
| SCA-002 | Package Manifest | npm lifecycle running hidden file | error | Regex: lifecycle script references dotfile or /tmp |
| SCA-003 | Package Manifest | setup.py os.system/subprocess | error | Regex: os.system, subprocess.call/run/Popen in setup.py |
| SCA-004 | Package Manifest | setup.py \_\_import\_\_/importlib | warning | Regex: dynamic import in setup.py |
| SCA-005 | Package Manifest | setup.py cmdclass override | warning | Regex: cmdclass with install/develop/build_ext |
| SCA-006 | Package Manifest | Gemfile non-rubygems source | warning | Regex: source URL not ending in rubygems.org |
| SCA-007 | Package Manifest | Cargo.toml build script | info | Regex: build = "build.rs" |
| SCA-008 | Package Manifest | composer.json suspicious scripts | error | Regex: lifecycle hook with curl/wget/bash/php -r |
| SCA-009 | Build Tampering | build.gradle exec commands | warning | Regex: exec block, commandLine, .execute() |
| SCA-010 | CI/CD Pipeline | Actions shell injection via inputs | error | Regex: run: with interpolated github.event fields |
| SCA-011 | CI/CD Pipeline | Actions self-hosted runner | warning | Regex: runs-on: self-hosted |
| SCA-012 | CI/CD Pipeline | pull\_request\_target + checkout PR | error | Regex: ref with github.event.pull_request.head |
| SCA-013 | CI/CD Pipeline | ACTIONS\_ALLOW\_UNSECURE\_COMMANDS | error | Regex: env var set to true |
| SCA-014 | CI/CD Pipeline | GITHUB\_ENV injection | error | Regex: >> $GITHUB_ENV with interpolated input |
| SCA-015 | CI/CD Pipeline | workflow\_run without filtering | warning | Regex: workflow_run with no branch filter |
| SCA-016 | CI/CD Pipeline | download-artifact risk | info | Regex: actions/download-artifact usage |
| SCA-017 | CI/CD Pipeline | write permissions on workflow | info | Regex: permissions with write-all/contents:write |
| SCA-018 | Git Config | .gitmodules suspicious host | warning | Regex: URL not pointing to github/gitlab/bitbucket |
| SCA-019 | Git Config | .gitattributes filter commands | warning | Regex: filter=, smudge=, clean= directives |
| SCA-020 | Git Config | Git hooks with network calls | error | Regex: curl/wget/nc/base64 in hook scripts |
| SCA-021 | Build Tampering | Makefile download + chmod +x | warning | Regex: curl/wget piped to chmod +x |
| SCA-022 | Build Tampering | Makefile curl without checksum | info | Regex: curl/wget with http URL |
| SCA-023 | Build Tampering | CMake execute\_process network | error | Regex: execute_process COMMAND with curl/wget |
| SCA-024 | Build Tampering | CMake file(DOWNLOAD) no hash | warning | Regex: file(DOWNLOAD without EXPECTED_HASH |
| SCA-025 | Build Tampering | Gradle/Maven non-standard repo | info | Regex: repository URL not matching known registries |
| SCA-026 | Dep Confusion | npm unscoped private package | warning | Regex: name with internal/private/corp prefix, no scope |
| SCA-027 | Dep Confusion | pip --extra-index-url | warning | Regex: --extra-index-url in any file |
| SCA-028 | Dep Confusion | .npmrc custom registry | info | Regex: registry pointing to non-npmjs.org |
| SCA-029 | Python | .pth file auto-execution | error | Regex: import statement in .pth file |
| SCA-030 | Python | conftest.py/\_\_init\_\_ network calls | warning | Regex: requests/urllib/subprocess in init files |
| SCA-031 | Python | base64 decode + exec pattern | error | Regex: b64decode followed by exec/eval/os.system |
| SCA-032 | Python | pip.conf custom index | info | Regex: index-url pointing to non-pypi.org |
| SCA-033 | Ruby | Gemfile git without ref pin | warning | Regex: git source without ref/tag/branch |
| SCA-034 | Ruby | gemspec native extensions | info | Regex: extensions array in gemspec |
| SCA-035 | Ruby | Gemfile eval/system call | error | Regex: eval, system, exec, backtick in Gemfile |
| SCA-036 | Go | go.mod remote replace directive | warning | Regex: replace => remote URL |
| SCA-037 | Go | go generate with network calls | warning | Regex: go:generate with curl/wget/bash |
| SCA-038 | Go | go.sum missing | warning | File-existence: go.mod without go.sum |
| SCA-039 | Rust | build.rs with network calls | error | Regex: reqwest/hyper/curl/TcpStream in build.rs |
| SCA-040 | Rust | Cargo.toml git dep without rev | warning | Regex: git source without rev= |
| SCA-041 | Rust | Cargo.toml proc-macro from git | error | Regex: proc-macro with git source |
| SCA-042 | Docker | ADD with remote URL | warning | Regex: ADD https:// in Dockerfile |
| SCA-043 | Docker | COPY --from untrusted image | warning | Regex: --from= not matching known stage names |
| SCA-044 | Docker | Secret in build ARG | error | Regex: ARG with PASSWORD/SECRET/TOKEN/API_KEY |
| SCA-045 | Docker | Multi-stage copy root | warning | Regex: COPY --from=stage / / |
| SCA-046 | Lock Integrity | npm lockfile non-standard URL | warning | Regex: resolved URL not pointing to npmjs.org |
| SCA-047 | Lock Integrity | yarn.lock non-standard registry | warning | Regex: resolved URL not yarnpkg/npmjs |
| SCA-048 | Lock Integrity | Lockfile without integrity hash | warning | Regex: resolved without nearby integrity |
| SCA-049 | Lock Integrity | pip requirements without hashes | info | Regex: pinned deps without --hash |
| SCA-050 | Config Risk | .npmrc auth token committed | error | Regex: _authToken in committed .npmrc |
| SCA-051 | Config Risk | .pypirc credentials committed | error | Regex: password/token in .pypirc |
| SCA-052 | Config Risk | .env with secrets committed | error | Regex: known secret keys with non-template values |
| SCA-053 | Config Risk | nuget.config credentials | error | Regex: ClearTextPassword in nuget config |
| SCA-054 | GitHub Actions | Cache poisoning risk | info | Regex: actions/cache in workflow |
| SCA-055 | GitHub Actions | Unpinned reusable workflow | warning | Regex: .yml@main/master/latest/vN |
| SCA-056 | GitHub Actions | Prod environment without protection | info | Regex: environment: production/prod/live |
| SCA-057 | GitHub Actions | Unknown third-party action | info | Regex: uses: not from known trusted orgs |
| SCA-058 | General | curl piped to shell | warning | Regex: curl/wget piped to bash/sh |
| SCA-059 | General | base64 decode in code | warning | Regex: base64 decode function calls |
| SCA-060 | General | Encoded payload execution | error | Regex: base64 decode piped to eval/exec/sh |
| SCA-061 | General | Hex/unicode encoded commands | warning | Regex: long \x or \u escape sequences |
| SCA-062 | General | Env var exfiltration pattern | error | Regex: HTTP call with env var interpolation |
| SCA-063 | General | DNS exfiltration pattern | error | Regex: dig/nslookup with variable interpolation |
| SCA-064 | General | Reverse shell pattern | error | Regex: /dev/tcp, bash -i, nc -e, socket+subprocess |
| SCA-065 | General | IP:port C2 beacon | warning | Regex: HTTP tool + hardcoded IP:port |
| SCA-066 | General | PATH manipulation/shadowing | info | Regex: PATH prepend in shell scripts |
| SCA-067 | Cross-cutting | Typosquatting indicator | error | Regex: known misspellings of popular packages |
| SCA-068 | Cross-cutting | Wildcard/any version dep | error | Regex: "*" or "latest" in dependency version |
| SCA-069 | GitHub Actions | Token leak to third-party | info | Regex: secrets.GITHUB_TOKEN usage |
| SCA-070 | Package Manifest | npm postinstall with obfuscated code | error | Regex: lifecycle script with node -e |

---

## Category Details

### 1. Package Manifest Poisoning (SCA-001 – SCA-008, SCA-070)

**What it is**: Attackers inject malicious code into package manifest files (`package.json`, `setup.py`, `Gemfile`, `composer.json`, `Cargo.toml`) that executes during installation — before the developer's code ever runs. Lifecycle scripts (`postinstall`, `preinstall`, `prepare`) are the primary vector.

**Real-world examples**:

- **axios compromise (2026)** — malicious `postinstall` script downloaded and executed a remote payload via `curl`
- **Mastra supply chain attack (2026)** — npm lifecycle script fetched second-stage payload from attacker-controlled CDN
- **Hades/Shai-Hulud PyPI campaigns (2026)** — `setup.py` used `os.system()` and `subprocess.Popen()` to harvest cloud credentials from CI environments
- **event-stream (2018)** — malicious dependency added with a `postinstall` hook that targeted a cryptocurrency wallet
- **ua-parser-js (2021)** — compromised maintainer account, lifecycle scripts installed cryptominers

**How cpm detects it**:

- Pattern match on lifecycle script declarations containing shell commands, network tools, or interpreters
- Detection of hidden file references (`./.<file>`, `/tmp/`) in install scripts
- Detection of `os.system()`, `subprocess.*`, dynamic imports, and `cmdclass` overrides in `setup.py`
- Detection of suspicious Composer and build.gradle scripts
- Detection of `node -e` inline execution in npm lifecycle scripts (obfuscation vector)

**Rule files**: `SCA-001.rule` through `SCA-008.rule`, `SCA-070.rule`

**Limitations**:

- Legitimate packages use lifecycle scripts (e.g., `node-gyp rebuild` for native modules). These checks flag the *pattern*, not the *intent*.
- Obfuscated payloads that split commands across multiple lines or use variable indirection may evade single-line regex.
- `setup.py` checks only catch direct calls — a malicious `setup.py` that imports from another file in the package will not be caught.

---

### 2. CI/CD Pipeline Attacks (SCA-010 – SCA-017)

**What it is**: GitHub Actions workflows are code that runs with elevated privileges — write access to repositories, access to secrets, ability to publish packages. Attackers exploit input interpolation, event triggers, and permission models to inject commands, escalate privileges, or exfiltrate secrets.

**Real-world examples**:

- **CVE-2026-35580 (Emissary)** — workflow dispatch inputs interpolated directly into `run:` blocks allowed arbitrary shell injection
- **TanStack attack (2026)** — `pull_request_target` event combined with `actions/checkout` of PR head ref gave fork PRs write access and secrets
- **tj-actions/changed-files (2025)** — compromised action exfiltrated secrets by modifying the action code post-review
- **codecov uploader (2021)** — CI script modified to exfiltrate environment variables containing tokens

**How cpm detects it**:

- Interpolation of untrusted `github.event.*` fields directly in `run:` blocks (SCA-010)
- `pull_request_target` combined with PR head checkout (SCA-012)
- Re-enabled deprecated unsafe commands (SCA-013)
- Untrusted input written to `$GITHUB_ENV`/`$GITHUB_OUTPUT`/`$GITHUB_PATH` (SCA-014)
- `workflow_run` without branch filtering (SCA-015)
- Artifact download from untrusted sources (SCA-016)
- Overly permissive workflow permissions (SCA-017)
- Self-hosted runner usage for potentially untrusted workloads (SCA-011)

**Rule files**: `SCA-010.rule` through `SCA-017.rule`

**Limitations**:

- Multi-line YAML structures are hard to correlate with single-line regex. The `pull_request_target` + checkout combination (SCA-012) requires the two patterns to appear in the same file, not necessarily adjacent.
- Permission escalation through transitive action dependencies (action A calls action B which has write access) is not detectable statically.
- Compromised actions that were legitimate at pin time require runtime signature verification, not static analysis.

---

### 3. Git Configuration Attacks (SCA-018 – SCA-020)

**What it is**: Git configuration files (`.gitmodules`, `.gitattributes`, committed hooks) can execute arbitrary code during clone, checkout, or stage operations — often without any visible prompt to the developer.

**Real-world examples**:

- **CVE-2024-32002** — crafted `.gitmodules` entries achieved remote code execution during `git clone` by exploiting case-insensitive filesystems
- **Git filter driver attacks** — `.gitattributes` `smudge`/`clean` filters execute arbitrary commands on every checkout/stage
- **Committed hook scripts** — repositories with `.githooks/` containing malicious scripts that run when `core.hooksPath` is set

**How cpm detects it**:

- `.gitmodules` URLs pointing to non-major hosting platforms (SCA-018)
- `.gitattributes` with `filter=`, `smudge=`, or `clean=` directives (SCA-019)
- Committed hook scripts containing network calls, encoded payloads, or interpreters (SCA-020)

**Rule files**: `SCA-018.rule` through `SCA-020.rule`

**Limitations**:

- Submodule attacks can use legitimate hosts (e.g., a compromised github.com repo). The check only flags non-major hosts.
- Filter drivers may be legitimate (e.g., Git LFS uses smudge/clean). The check flags the *capability*, requiring manual review.
- Hook scripts inside `.git/hooks/` are not committed and thus not scannable by cpm.

---

### 4. Build System Tampering (SCA-009, SCA-021 – SCA-025)

**What it is**: Build files (`Makefile`, `CMakeLists.txt`, `build.gradle`) execute during compilation or configuration. Attackers who compromise build files can download and run arbitrary code with the developer's full privileges — before any application code is compiled.

**Real-world examples**:

- **CVE-2024-3094 (XZ Utils)** — build system scripts extracted an obfuscated backdoor from test fixtures, achieving CVSS 10.0. The attack hid payload extraction in `Makefile.am` and `configure.ac`.
- **arrayref/onering Rust attacks (2026)** — `build.rs` downloaded remote payloads during `cargo build`
- **Codecov Bash Uploader (2021)** — Makefile downloaded a script via curl without checksum verification; the script was later compromised

**How cpm detects it**:

- Makefile downloading executables with `curl`/`wget` + `chmod +x` (SCA-021)
- Makefile downloading without checksum verification (SCA-022)
- CMake `execute_process` with network commands (SCA-023)
- CMake `file(DOWNLOAD)` without `EXPECTED_HASH` (SCA-024)
- Gradle/Maven downloading from non-standard repositories (SCA-025)
- Gradle build files with shell execution (SCA-009)

**Rule files**: `SCA-009.rule`, `SCA-021.rule` through `SCA-025.rule`

**Limitations**:

- Many legitimate build systems download toolchains (e.g., `rustup`, `nvm`). The check flags the pattern; checksum verification is the mitigation.
- Multi-step obfuscation (like XZ Utils' sed|tr|head|tail chain) may evade simple regex. The existing `SC-SEC-013-xz-backdoor.rule` covers the XZ-specific pattern.
- Gradle plugin resolution happens at runtime and is not captured by static file analysis.

---

### 5. Dependency Confusion (SCA-026 – SCA-028)

**What it is**: Dependency confusion exploits the way package managers resolve names across multiple registries. When a private package name exists on both a private and public registry, the package manager may prefer the public version (usually the higher version number). Attackers claim private package names on public registries and publish trojanized versions.

**Real-world examples**:

- **Alex Birsan disclosure (2021)** — demonstrated dependency confusion across npm, PyPI, and RubyGems, affecting Apple, Microsoft, PayPal, and others
- **Microsoft internal packages (2026)** — 33+ malicious packages published on npm targeting unscoped internal package names
- **PyTorch nightly (2022)** — `torchtriton` dependency confusion attack via PyPI `--extra-index-url`

**How cpm detects it**:

- npm packages with private-sounding names (`*-internal`, `private-*`, `corp-*`) without a scope prefix (SCA-026)
- `--extra-index-url` in pip configuration (SCA-027)
- Custom registry in `.npmrc` without explicit scope mapping (SCA-028)

**Rule files**: `SCA-026.rule` through `SCA-028.rule`

**Limitations**:

- False positives on legitimate unscoped packages that happen to contain "internal" or "private" in the name.
- The `--extra-index-url` check flags all usage, including legitimate multi-registry setups. The fix is to use `--index-url` instead.
- True dependency confusion requires knowledge of the private registry's package list, which cpm doesn't have.

---

### 6. Python-Specific (SCA-029 – SCA-032)

**What it is**: Python's import system and packaging tools provide multiple code execution paths during installation and runtime startup. `.pth` files execute on interpreter start, `__init__.py` runs on import, and `pip.conf` controls which registry supplies packages.

**Real-world examples**:

- **Hades/Shai-Hulud campaigns (2026)** — used `.pth` files with `import` statements in wheel packages to execute on every Python startup
- **TeamPCP attacks (2026)** — `base64.b64decode()` + `exec()` pattern in setup.py to decode and run obfuscated payloads
- **PyPI malware campaigns (ongoing)** — `__init__.py` with hidden `requests.post()` calls to exfiltrate environment variables

**How cpm detects it**:

- `.pth` files containing `import` statements (SCA-029)
- `conftest.py`/`__init__.py` with network calls or subprocess execution (SCA-030)
- `base64.b64decode` followed by `exec`/`eval`/`os.system` (SCA-031)
- `pip.conf` pointing to non-PyPI index (SCA-032)

**Rule files**: `SCA-029.rule` through `SCA-032.rule`

**Limitations**:

- `.pth` files are typically in `site-packages`, not in project repos. This check is most useful when scanning virtual environments or wheel contents.
- Legitimate `conftest.py` may use `subprocess` for test fixtures. Manual review is needed.
- The base64+exec pattern catches the common form but not multi-step obfuscation (decode in one function, exec in another).

---

### 7. Ruby-Specific (SCA-033 – SCA-035)

**What it is**: Ruby's `Gemfile` is executable Ruby code, and gems with native extensions compile C code during install. This gives attackers code execution during `bundle install` through multiple vectors.

**Real-world examples**:

- **rest-client compromise (2019)** — malicious code in a gem evaluated remote content at runtime
- **bootstrap-sass (2019)** — compromised gem included a backdoor that executed at require time
- **Strong_password (2019)** — gem modified to fetch and eval remote code

**How cpm detects it**:

- Git-sourced gems without a pinned ref/tag/commit (SCA-033)
- Gemspec declaring native extensions (SCA-034)
- `eval`, `system`, `exec`, or backtick execution in Gemfile (SCA-035)

**Rule files**: `SCA-033.rule` through `SCA-035.rule`

**Limitations**:

- Many legitimate gems use native extensions (e.g., `nokogiri`, `pg`). SCA-034 is informational, not an error.
- Backtick detection may false-positive on Markdown files if they match the Gemfile target pattern.
- Pinned git refs can still point to compromised commits; pinning reduces risk but doesn't eliminate it.

---

### 8. Go-Specific (SCA-036 – SCA-038)

**What it is**: Go modules use `go.mod` for dependency management and `//go:generate` for code generation. The `replace` directive can redirect module resolution, and missing `go.sum` disables checksum verification.

**Real-world examples**:

- **Go module typosquatting (2023)** — malicious modules with names similar to popular Go packages
- **Supply chain through replace directives** — redirect trusted modules to attacker-controlled forks during development, accidentally merged to production

**How cpm detects it**:

- `replace` directive pointing to remote URLs (SCA-036)
- `//go:generate` with network commands (SCA-037)
- `go.mod` without accompanying `go.sum` (SCA-038, file-existence check)

**Rule files**: `SCA-036.rule` through `SCA-038.rule`

**Limitations**:

- Remote `replace` directives are common during local development. The check is a warning, not an error.
- `go.sum` absence check requires file-existence logic, not regex — implementation uses the `absence` engine type.
- Go's module proxy (`GOPROXY=proxy.golang.org`) provides checksum verification even without local `go.sum`, reducing the severity.

---

### 9. Rust-Specific (SCA-039 – SCA-041)

**What it is**: Cargo build scripts (`build.rs`) execute during compilation with full system access. Procedural macros execute at compile time. Both are powerful code execution points during `cargo build`.

**Real-world examples**:

- **onering crate (2026)** — `build.rs` exfiltrated git data via HTTP during compilation
- **arrayref typosquat (2026)** — typosquatted crate with `build.rs` that downloaded and executed a remote payload
- **crates.io malware campaigns (2023+)** — multiple crates using `build.rs` for data exfiltration

**How cpm detects it**:

- `build.rs` containing network libraries (reqwest, hyper, curl) or `TcpStream` (SCA-039)
- `Cargo.toml` git dependencies without pinned rev (SCA-040)
- Procedural macros sourced from git (SCA-041)

**Rule files**: `SCA-039.rule` through `SCA-041.rule`

**Limitations**:

- Some legitimate build scripts use network access (e.g., downloading prebuilt binaries for FFI). SCA-039 is an error because this should be rare and audited.
- The proc-macro check (SCA-041) only catches git-sourced macros. A malicious proc-macro on crates.io passes this check.
- Transitive `build.rs` execution through dependencies is not detectable by scanning the top-level `Cargo.toml`.

---

### 10. Docker Supply Chain (SCA-042 – SCA-045)

**What it is**: Dockerfiles define build instructions that download, copy, and execute code. `ADD` fetches remote URLs, `COPY --from` pulls from external images, `ARG` values persist in image metadata, and multi-stage builds can leak secrets across stages.

**Real-world examples**:

- **Exposed Docker images on Docker Hub** — images with embedded AWS credentials, SSH keys, and API tokens
- **Docker Hub typosquatting (2023)** — malicious images with names mimicking popular base images
- **Cryptomining images** — legitimate-looking images with hidden mining payloads in intermediate layers

**How cpm detects it**:

- `ADD` with remote HTTP(S) URLs (SCA-042)
- `COPY --from=` referencing non-standard stage names (SCA-043)
- `ARG` with secret-indicating names (PASSWORD, TOKEN, SECRET, API_KEY) (SCA-044)
- Multi-stage `COPY --from=stage / /` copying the entire root (SCA-045)

**Rule files**: `SCA-042.rule` through `SCA-045.rule`

**Limitations**:

- `ADD` with remote URLs has legitimate uses (e.g., downloading release tarballs). The check is a warning; checksum verification is the mitigation.
- `COPY --from` with custom stage names that don't match the allowlist generates false positives. The allowlist (`build`, `builder`, `base`, `deps`, `compile`, `stage`) covers common patterns.
- Secret detection by `ARG` name is heuristic — secrets with non-obvious names (e.g., `ARG MYVAR`) will not be caught.

---

### 11. Lock File Integrity (SCA-046 – SCA-049)

**What it is**: Lock files (`package-lock.json`, `yarn.lock`, `requirements.txt`) pin exact versions and registry URLs. Tampered lock files can redirect downloads to attacker-controlled registries or remove integrity hashes, allowing package substitution.

**Real-world examples**:

- **CVE-2025-69263 (pnpm)** — missing integrity hashes allowed package substitution without verification
- **Lockfile injection attacks** — PRs that modify only `package-lock.json` to change `resolved` URLs, redirecting package downloads
- **Dependency confusion via lockfile** — modified lockfiles pointing `resolved` to a malicious registry

**How cpm detects it**:

- `package-lock.json` with `resolved` URLs pointing to non-npmjs.org registries (SCA-046)
- `yarn.lock` with non-standard registry URLs (SCA-047)
- `package-lock.json` entries with `resolved` but missing `integrity` hash (SCA-048)
- `requirements.txt` with pinned versions but no `--hash` verification (SCA-049)

**Rule files**: `SCA-046.rule` through `SCA-049.rule`

**Limitations**:

- Organizations using private registries (Artifactory, Nexus) will see false positives on SCA-046/047. These should be configured as allowed registries.
- The integrity hash adjacency check (SCA-048) is imprecise with single-line regex; it may miss entries where `integrity` appears several lines below `resolved`.
- pip hash pinning (SCA-049) is informational — most Python projects don't use `--require-hashes`, and adding it is a significant workflow change.

---

### 12. Config File Risks (SCA-050 – SCA-053)

**What it is**: Configuration files for package managers and registries (`.npmrc`, `.pypirc`, `.env`, `nuget.config`) often contain authentication tokens. When committed to version control, these credentials are exposed to anyone with repository access — including automated scrapers that mine public repositories.

**Real-world examples**:

- **GitHub secret scanning alerts** — GitHub reports finding >40 million secrets committed to public repos in 2025
- **npm token exposure** — committed `.npmrc` files with `_authToken` allowed attackers to publish malicious packages under legitimate scopes
- **.env file exposure** — database credentials, AWS keys, and API tokens routinely found in committed `.env` files

**How cpm detects it**:

- `.npmrc` with `_authToken` or `_auth` values (SCA-050)
- `.pypirc` with `password` or `token` values (SCA-051)
- `.env` files with known secret variable names containing non-template values (SCA-052)
- `nuget.config` with `ClearTextPassword` (SCA-053)

**Rule files**: `SCA-050.rule` through `SCA-053.rule`

**Limitations**:

- `.env.example` files with placeholder values may false-positive if the placeholder looks like a real value. The regex excludes `${...}` template syntax.
- Secrets with non-standard variable names (e.g., `MY_CUSTOM_KEY=abc123`) will not be caught.
- This overlaps with `check-secrets-fast.sh` but targets config-file-specific patterns rather than general API key regex.

---

### 13. GitHub Actions Specific (SCA-054 – SCA-057, SCA-069)

**What it is**: Beyond the pipeline injection attacks in Category 2, GitHub Actions has structural security concerns: cache poisoning across workflow runs, unpinned reusable workflows, production environment deployments without protection rules, and secrets passed to unvetted third-party actions.

**Real-world examples**:

- **GitHub Actions cache poisoning (2022)** — researchers demonstrated cache injection from fork PRs affecting base branch workflows
- **Reusable workflow compromise** — workflows pinned to mutable refs (main/master) can change behavior after review
- **Third-party action compromise (tj-actions, 2025)** — trusted action modified to exfiltrate secrets

**How cpm detects it**:

- `actions/cache` usage as a poisoning risk indicator (SCA-054)
- Reusable workflows pinned to mutable refs instead of SHA (SCA-055)
- Production environment declarations without protection context (SCA-056)
- Third-party actions not from known trusted organizations (SCA-057)
- `GITHUB_TOKEN` passed via secrets context (SCA-069)

**Rule files**: `SCA-054.rule` through `SCA-057.rule`, `SCA-069.rule`

**Limitations**:

- SCA-054 and SCA-057 are informational — `actions/cache` and third-party actions are normal. These are awareness checks.
- Environment protection rules are configured in GitHub Settings, not in the workflow file. SCA-056 can only flag the *declaration*, not verify that protection is actually configured.
- The trusted org allowlist (`actions/`, `github/`, `azure/`, `aws-actions/`, `docker/`, `hashicorp/`, `google-github-actions/`, `codecov/`, `softprops/`, `dorny/`, `peter-evans/`) may need expansion per organization.

---

### 14. General / Cross-Cutting (SCA-058 – SCA-066)

**What it is**: Attack patterns that appear across all languages and ecosystems — payload obfuscation (base64, hex encoding), data exfiltration (environment variables, DNS), reverse shells, C2 beacons, and binary shadowing through PATH manipulation.

**Real-world examples**:

- **TeamPCP/Shai-Hulud (2026)** — cross-ecosystem attacks using `base64 --decode | bash` and `eval(atob(...))` as the primary obfuscation technique
- **DNS exfiltration in CI** — stolen tokens encoded as DNS query labels to bypass firewall egress rules
- **Reverse shells in npm packages** — packages with `/dev/tcp/` or `nc -e` backdoors discovered monthly on npm
- **curl | bash** — ubiquitous installation pattern that downloads and immediately executes unverified code

**How cpm detects it**:

- `curl`/`wget` piped to `bash`/`sh` (SCA-058)
- Base64 decode function calls (SCA-059)
- Encoded payload + execution combination (SCA-060)
- Long hex/unicode escape sequences (SCA-061)
- HTTP calls with environment variable interpolation (SCA-062)
- DNS queries with variable interpolation or known exfiltration domains (SCA-063)
- Reverse shell patterns: `/dev/tcp/`, `bash -i`, `nc -e`, socket+subprocess (SCA-064)
- HTTP tools with hardcoded IP:port combinations (SCA-065)
- PATH prepend patterns that could shadow system binaries (SCA-066)

**Rule files**: `SCA-058.rule` through `SCA-066.rule`

**Limitations**:

- Base64 decoding (SCA-059) has many legitimate uses (JWT parsing, image encoding, API payloads). It's a warning that requires context.
- The encoded payload execution check (SCA-060) is high-confidence but can be evaded by splitting decode and execute across functions or files.
- Environment variable exfiltration (SCA-062) may false-positive on legitimate API calls that include auth tokens from env vars. The pattern looks for the combination of HTTP client + env var access.
- IP:port detection (SCA-065) will false-positive on test configurations and infrastructure code that legitimately references IP addresses.

---

### 15. Language-Ecosystem Cross-Cutting (SCA-067 – SCA-070)

**What it is**: Patterns that span multiple ecosystems — typosquatting (misspelled package names), wildcard version constraints, GitHub token leaks, and obfuscated npm lifecycle scripts.

**Real-world examples**:

- **Typosquatting at scale** — attackers register `reqeusts`, `lodsah`, `collors`, `expresss` across npm, PyPI, and RubyGems
- **Wildcard dependencies** — `"*"` or `"latest"` in `package.json` allows any version, including a malicious one published with a higher version number
- **GITHUB_TOKEN exposure** — workflows passing `${{ secrets.GITHUB_TOKEN }}` to third-party actions give those actions full API access

**How cpm detects it**:

- Known misspellings of popular packages across npm, pip, gems, cargo, and go (SCA-067)
- Wildcard (`*`), `latest`, or `>=0.0.0` version constraints (SCA-068)
- `secrets.GITHUB_TOKEN` interpolation (SCA-069)
- npm lifecycle scripts with inline `node -e` execution (SCA-070)

**Rule files**: `SCA-067.rule` through `SCA-070.rule`

**Limitations**:

- The typosquatting dictionary (SCA-067) is finite and maintained manually. New typosquats appear daily. This catches known variants but not novel ones.
- Wildcard detection only covers `package.json` and `composer.json`. Other ecosystems have different wildcard syntax.
- `GITHUB_TOKEN` has read-only permissions by default in many contexts. SCA-069 is informational, flagging usage for awareness.

---

## Implementation

All 70 checks are implemented as `.rule` files in `rules/supply-chain/`, using cpm's declarative rule engine (see [R-020](R-020-portable-rule-engine.md) and [R-021](R-021-check-rule-categories.md)).

### Rule file format

Each `.rule` file follows cpm's standard format:

```yaml
id: SCA-001
title: npm postinstall script with network call
category: security
severity: error
engine: pattern
target:
  filenames: package.json
  exclude_paths: node_modules/ .git/
patterns:
  - regex: '"(postinstall|preinstall|install|prepare|prepublish)"\s*:\s*"[^"]*\b(curl|wget|node\s+-e|python|bash\s+-c|powershell|nc\s|ncat\s)'
    message: "Lifecycle script executes network/shell command — supply chain attack vector"
fix: Remove network-calling lifecycle scripts. Use --ignore-scripts during install.
references:
  - https://docs.npmjs.com/cli/v10/using-npm/scripts
  - https://slsa.dev/spec/v1.0/threats
```

### Engine types used

| Engine | Checks | Description |
|--------|--------|-------------|
| `pattern` | 69 | Regex match on file content — presence of pattern indicates risk |
| `absence` | 1 | File-existence check (SCA-038: go.sum missing alongside go.mod) |

### Naming convention

Following cpm's naming convention ([conventions.md](../conventions.md)):

- **Rule ID**: `SCA-{NNN}` (Supply Chain Attack, sequential)
- **File name**: `SCA-{NNN}-{short-slug}.rule`
- **Finding type**: `supply-chain` category in the findings database

### Integration with cpm

```bash
# Run all supply chain checks
cpm check --category supply-chain

# Run checks on a specific file
cpm scan . --rules supply-chain

# Show supply chain findings
cpm findings --category supply-chain
```

### Rule distribution by target

| Target files | Rules | Focus |
|-------------|-------|-------|
| `package.json` | 6 | npm lifecycle scripts, version constraints |
| `.github/workflows/*.yml` | 13 | CI/CD injection, permissions, pinning |
| `Dockerfile` | 4 | Remote ADD, secrets in ARG, multi-stage leaks |
| `setup.py` | 3 | Python install-time execution |
| `Makefile` / `CMakeLists.txt` | 5 | Build system downloads and execution |
| `Cargo.toml` / `build.rs` | 4 | Rust build-time execution |
| `go.mod` / `*.go` | 3 | Go module redirects and code generation |
| `Gemfile` / `*.gemspec` | 3 | Ruby install-time execution |
| Lock files | 4 | Registry URLs, integrity hashes |
| Config files (`.npmrc`, `.env`, etc.) | 5 | Committed credentials |
| Cross-language source files | 13 | Obfuscation, exfiltration, reverse shells |
| Git config (`.gitmodules`, `.gitattributes`) | 3 | Git-level execution vectors |

---

## References

### Frameworks and standards

- **SLSA (Supply-chain Levels for Software Artifacts)** — <https://slsa.dev> — Framework for end-to-end software supply chain integrity. cpm's checks align with SLSA threat model categories (source threats, build threats, dependency threats).
- **OpenSSF Scorecard** — <https://scorecard.dev> — Automated security assessment for open source projects. Checks like pinned dependencies, branch protection, and token permissions overlap with SCA-040, SCA-055, SCA-017.
- **CISA Supply Chain Risk Management** — <https://www.cisa.gov/supply-chain> — US government guidance on identifying and mitigating software supply chain risks.
- **NIST SP 800-218 (SSDF)** — Secure Software Development Framework. Provides the organizational context for supply chain security practices.
- **NIST SP 800-161** — Cybersecurity Supply Chain Risk Management. Federal guidance on managing supply chain risks.
- **CWE-1357** — Reliance on Insufficiently Trustworthy Component. The CWE entry that covers supply chain trust.

### Attack research and databases

- **Birsan, Alex (2021)** — "Dependency Confusion: How I Hacked Into Apple, Microsoft and Dozens of Other Companies" — <https://medium.com/@alex.birsan/dependency-confusion-4a5d60fec610>
- **Socket.dev Research** — Ongoing supply chain attack analysis across npm, PyPI, and Go — <https://socket.dev/blog>
- **OpenSSF Package Analysis** — Automated detection of malicious packages — <https://github.com/ossf/package-analysis>
- **Phylum Research** — Supply chain attack disclosures — <https://blog.phylum.io>
- **Snyk Vulnerability Database** — <https://security.snyk.io>

### CVEs and incidents referenced

| CVE / Incident | Year | Vector | Category |
|---------------|------|--------|----------|
| CVE-2024-3094 (XZ Utils) | 2024 | Build system backdoor | Build Tampering |
| CVE-2024-32002 (Git) | 2024 | Crafted submodules RCE | Git Config |
| CVE-2025-69263 (pnpm) | 2025 | Missing integrity hashes | Lock Integrity |
| CVE-2026-35580 (Emissary) | 2026 | Actions shell injection | CI/CD Pipeline |
| event-stream (npm) | 2018 | Malicious dependency | Package Manifest |
| ua-parser-js (npm) | 2021 | Compromised maintainer | Package Manifest |
| codecov uploader | 2021 | CI script modification | Build Tampering |
| PyTorch torchtriton | 2022 | Dependency confusion | Dep Confusion |
| tj-actions/changed-files | 2025 | Compromised action | GitHub Actions |
| TanStack | 2026 | pull_request_target | CI/CD Pipeline |
| axios (npm) | 2026 | Lifecycle script | Package Manifest |
| Mastra (npm) | 2026 | Lifecycle script | Package Manifest |
| Hades/Shai-Hulud (PyPI) | 2026 | setup.py + .pth | Python |
| onering/arrayref (Rust) | 2026 | build.rs | Rust |

### cpm internal references

- @see [R-020: Portable Rule Engine](R-020-portable-rule-engine.md) — rule file format and engine architecture
- @see [R-021: Check Rule Categories](R-021-check-rule-categories.md) — category breakdown and engine types
- @see [ADR-013: Product Positioning](../adrs/adr-013-product-positioning.md) — cpm philosophy and compliance layering
- @see [ADR-014: Findings Database](../adrs/adr-014-findings-database.md) — JSONL findings format
- @see [ADR-020: Product Vision](../adrs/adr-020-product-vision.md) — shift-left, one binary, zero friction
