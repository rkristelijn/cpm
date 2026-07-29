class Cpm < Formula
  desc "Code project maturity — quality layer between git and your code"
  homepage "https://github.com/rkristelijn/cpm"
  license "MIT"
  version "0.7.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rkristelijn/cpm/releases/download/v0.7.0/cpm-macos-arm64.tar.gz"
      sha256 "1d972b625b1d522249aeb2612daf3fc5aa6d4b6568daad511ff83fc613e26382"
    else
      url "https://github.com/rkristelijn/cpm/releases/download/v0.7.0/cpm-macos-amd64.tar.gz"
      sha256 "1d972b625b1d522249aeb2612daf3fc5aa6d4b6568daad511ff83fc613e26382"
    end
  end

  on_linux do
    url "https://github.com/rkristelijn/cpm/releases/download/v0.7.0/cpm-linux-amd64.tar.gz"
    sha256 "aa285f6c20cde161f92c24c01250fecda96e889af5433c8e5a1eaf9727aee4a3"
  end

  def install
    bin.install "cpm"
  end

  test do
    assert_match "cpm", shell_output("#{bin}/cpm help")
  end
end
