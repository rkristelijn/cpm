class Cpm < Formula
  desc "Code project maturity — quality layer between git and your code"
  homepage "https://github.com/rkristelijn/cpm"
  license "MIT"
  version "0.4.1"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rkristelijn/cpm/releases/download/v0.4.1/cpm-macos-arm64.tar.gz"
      sha256 "33f296f2d7de6b25dc48332f5c904e17a5d01297398c2e2744208d80cb6b70ba"
    else
      url "https://github.com/rkristelijn/cpm/releases/download/v0.4.1/cpm-macos-amd64.tar.gz"
      sha256 "33f296f2d7de6b25dc48332f5c904e17a5d01297398c2e2744208d80cb6b70ba"
    end
  end

  on_linux do
    url "https://github.com/rkristelijn/cpm/releases/download/v0.4.1/cpm-linux-amd64.tar.gz"
    sha256 "49badb4ddab2bb6ef0bf89d929c3b852921dcb1c14ee63c6deb482dd63c3b998"
  end

  def install
    bin.install "cpm"
  end

  test do
    assert_match "cpm", shell_output("#{bin}/cpm help")
  end
end
