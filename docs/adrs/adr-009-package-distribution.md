---
summary: Distribute cpm via brew, apt, pacman, and curl one-liner.
status: proposed
---

# ADR-009: Package Distribution

## Context

cpm should be installable with one command on any platform, like any modern CLI tool.

## Decision

### Phase 1 (now): curl one-liner + local install

```bash
curl -fsSL https://raw.githubusercontent.com/rkristelijn/cpm/main/install.sh | bash
```

Installs to `~/.local/bin/cpm` + `~/.local/share/cpm/`.

### Phase 2: Homebrew tap

```bash
brew tap rkristelijn/cpm
brew install cpm
```

Requires:

- `homebrew-cpm` repo with Formula
- GitHub Releases with cross-compiled binaries (macOS arm64, Linux x64)
- Checksums in release assets

Formula template:

```ruby
class Cpm < Formula
  desc "Compliance Process Management — universal quality framework"
  homepage "https://github.com/rkristelijn/cpm"
  url "https://github.com/rkristelijn/cpm/releases/download/v#{version}/cpm-darwin-arm64.tar.gz"
  sha256 "..."

  def install
    bin.install "cpm"
    share.install "lib" => "cpm"
  end
end
```

### Phase 3: System packages

| Platform | Method | Repo |
|----------|--------|------|
| Arch/Manjaro | AUR PKGBUILD | `aur/cpm` |
| Debian/Ubuntu | `.deb` in releases | download + dpkg |
| Fedora/RHEL | `.rpm` in releases | download + rpm |
| Nix | flake | `github:rkristelijn/cpm` |
| Alpine | APKBUILD | future |

### Phase 4: Self-update

```bash
cpm self-update    # downloads latest from GitHub Releases
```

## Prerequisites for Phase 2+

1. Cross-compile binary for macOS arm64 + Linux x64
2. GitHub Actions release workflow (tag → build → upload)
3. Semantic versioning with CHANGELOG
4. Checksum verification in install script

## References

- @see install.sh (Phase 1 implementation)
- @see docs/adrs/adr-008-rebrand-compliance-process-management.md
