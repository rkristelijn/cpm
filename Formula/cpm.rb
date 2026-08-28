class Cpm < Formula
  desc "Code project maturity — quality layer between git and your code"
  homepage "https://github.com/rkristelijn/cpm"
  license "MIT"
  version "0.8.1"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rkristelijn/cpm/releases/download/v0.8.1/cpm-macos-arm64.tar.gz"
      sha256 "fba64b70c939d533be2cdac9ea55e810d01e512e0594bb4c407fdcdb0ec7ebe7"
    else
      url "https://github.com/rkristelijn/cpm/releases/download/v0.8.1/cpm-macos-amd64.tar.gz"
      sha256 "b6dbf4e9b51c1edb948475b6ec26146c6206a3607d78173420c42b8b59088b2f"
    end
  end

  on_linux do
    url "https://github.com/rkristelijn/cpm/releases/download/v0.8.1/cpm-linux-amd64.tar.gz"
    sha256 "ac6300cae9fe4612453c5ec75850e0da910858c728b2c450f3b7d2c64f89f376"
  end

  def install
    bin.install "cpm"
  end

  test do
    assert_match "cpm", shell_output("#{bin}/cpm help")
  end
end
