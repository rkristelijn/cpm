#!/usr/bin/env bash
# scripts/formula.sh — generate Homebrew formula
# Usage: bash scripts/formula.sh <version> <sha_arm64> <sha_amd64> <sha_linux>
set -o errexit -o nounset -o pipefail

VERSION="${1:?}" SHA_ARM64="${2:?}" SHA_AMD64="${3:?}" SHA_LINUX="${4:?}"

cat <<EOF
class Cpm < Formula
  desc "Code project maturity — quality layer between git and your code"
  homepage "https://github.com/rkristelijn/cpm"
  license "MIT"
  version "${VERSION}"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rkristelijn/cpm/releases/download/v${VERSION}/cpm-macos-arm64.tar.gz"
      sha256 "${SHA_ARM64}"
    else
      url "https://github.com/rkristelijn/cpm/releases/download/v${VERSION}/cpm-macos-amd64.tar.gz"
      sha256 "${SHA_AMD64}"
    end
  end

  on_linux do
    url "https://github.com/rkristelijn/cpm/releases/download/v${VERSION}/cpm-linux-amd64.tar.gz"
    sha256 "${SHA_LINUX}"
  end

  def install
    bin.install "cpm"
  end

  test do
    assert_match "cpm", shell_output("#{bin}/cpm help")
  end
end
EOF
