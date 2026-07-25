class Cpm < Formula
  desc "Code project maturity — quality layer between git and your code"
  homepage "https://github.com/rkristelijn/cpm"
  license "MIT"
  version "0.6.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rkristelijn/cpm/releases/download/v0.6.0/cpm-macos-arm64.tar.gz"
      sha256 "a40a5f29919f06300bf2d9277ce6fa6b4956ce7775e03919770d36ebf9a1f995"
    else
      url "https://github.com/rkristelijn/cpm/releases/download/v0.6.0/cpm-macos-amd64.tar.gz"
      sha256 "a40a5f29919f06300bf2d9277ce6fa6b4956ce7775e03919770d36ebf9a1f995"
    end
  end

  on_linux do
    url "https://github.com/rkristelijn/cpm/releases/download/v0.6.0/cpm-linux-amd64.tar.gz"
    sha256 "02001b27a1d2696f43127c50c40180ce1f885bd3ffd96a4d145265509e3de5c4"
  end

  def install
    bin.install "cpm"
  end

  test do
    assert_match "cpm", shell_output("#{bin}/cpm help")
  end
end
