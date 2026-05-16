# Roadmap: CPM Distribution (brew / apt / npx)

> Concrete tasks to go from `bash install.sh` to `brew install cpm`.

## Prerequisites (must be done first)

- [ ] **VERSION file**: Create `VERSION` with `0.2.0` in repo root
- [ ] **CHANGELOG.md**: Start with current state, follow keepachangelog.com format
- [ ] **Git tag**: `git tag v0.2.0` on stable commit
- [ ] **LICENSE**: Add MIT license file (required for all package managers)
- [ ] **`cpm --version`**: Output version from VERSION file

## Phase 1: GitHub Releases (week 1)

Goal: automated tarball on every tag push.

- [ ] Create `.github/workflows/release.yml`:

  ```yaml
  on:
    push:
      tags: ['v*']
  jobs:
    release:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - run: |
            tar czf cpm-${GITHUB_REF_NAME}.tar.gz \
              cpm lib/ checks/ install.sh VERSION LICENSE
        - uses: softprops/action-gh-release@v2
          with:
            files: cpm-*.tar.gz
            generate_release_notes: true
  ```

- [ ] Test: push `v0.2.0` tag → release appears with tarball
- [ ] Update `install.sh` to download from GitHub Releases (not just local)

## Phase 2: Homebrew tap (week 2)

Goal: `brew tap rkristelijn/cpm && brew install cpm`

- [ ] Create repo `github.com/rkristelijn/homebrew-cpm`
- [ ] Add `Formula/cpm.rb`:

  ```ruby
  class Cpm < Formula
    desc "Compliance Process Management — universal quality framework"
    homepage "https://github.com/rkristelijn/cpm"
    url "https://github.com/rkristelijn/cpm/releases/download/v0.2.0/cpm-v0.2.0.tar.gz"
    sha256 "PLACEHOLDER"
    license "MIT"

    def install
      bin.install "cpm"
      share.install "lib" => "cpm/lib"
      share.install "checks" => "cpm/checks"
      # Patch CPM_HOME to point to Cellar
      inreplace bin/"cpm", "$HOME/.local/share/cpm", "#{share}/cpm"
    end

    test do
      assert_match "cpm", shell_output("#{bin}/cpm status")
    end
  end
  ```

- [ ] Add CI step: after release, update formula SHA + URL automatically
- [ ] Test: `brew install --build-from-source rkristelijn/cpm/cpm`

## Phase 3: apt / deb package (week 3)

Goal: `sudo apt install ./cpm_0.2.0_all.deb`

- [ ] Create `packaging/deb/` structure:

  ```text
  packaging/deb/
  ├── DEBIAN/
  │   └── control
  └── usr/
      ├── bin/cpm
      └── share/cpm/{lib,checks}
  ```

- [ ] `DEBIAN/control`:

  ```text
  Package: cpm
  Version: 0.2.0
  Architecture: all
  Maintainer: rkristelijn
  Description: Compliance Process Management
  Depends: bash (>= 4.0), coreutils
  ```

- [ ] Add to release workflow: `dpkg-deb --build` → attach `.deb` to release
- [ ] Optional: PPA for `apt-get install` (requires Launchpad account)

## Phase 4: npx wrapper (week 3-4)

Goal: `npx @rkristelijn/cpm check`

- [ ] Create `packaging/npm/package.json`:

  ```json
  {
    "name": "@rkristelijn/cpm",
    "version": "0.2.0",
    "bin": { "cpm": "./bin/cpm" },
    "os": ["darwin", "linux"],
    "files": ["bin/", "lib/", "checks/"]
  }
  ```

- [ ] `bin/cpm` = the wrapper script with `CPM_HOME` pointing to package dir
- [ ] Add to release workflow: `npm publish --access public`
- [ ] Test: `npx @rkristelijn/cpm status`

## Phase 5: Self-update (week 4)

- [ ] `cpm self-update` command:
  - Fetch latest release from GitHub API
  - Compare with local VERSION
  - Download + replace in-place
- [ ] Version check on `cpm status` (notify if outdated)

---

## Dependency matrix

| Channel | Requires | Platform |
|---------|----------|----------|
| curl install.sh | bash, curl | all |
| brew | macOS, Linux (linuxbrew) | macOS primary |
| apt/deb | dpkg | Debian/Ubuntu |
| npx | node 18+ | all |
| self-update | curl, GitHub API | all |

## Non-goals (for now)

- Windows support (bash not native)
- Arch AUR / Nix flake (Phase 3+ in ADR-009)
- Binary compilation (bash is sufficient, no cross-compile needed)

## Success criteria

- [ ] `brew install rkristelijn/cpm/cpm && cpm status` works
- [ ] `curl ... | bash && cpm check` works on fresh Ubuntu
- [ ] `npx @rkristelijn/cpm check` works without prior install
- [ ] All channels install same version (single source of truth: VERSION file)
