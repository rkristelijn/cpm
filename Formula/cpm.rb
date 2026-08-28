class Cpm < Formula
  desc "Code project maturity — quality layer between git and your code"
  homepage "https://github.com/rkristelijn/cpm"
  license "MIT"
  version "0.8.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rkristelijn/cpm/releases/download/v0.8.0/cpm-macos-arm64.tar.gz"
      sha256 "b45a9c4293fed8e7da4edf6b10b19f947e2c774b43c69e9e0e31c57776f9e222"
    else
      url "https://github.com/rkristelijn/cpm/releases/download/v0.8.0/cpm-macos-amd64.tar.gz"
      sha256 "b45a9c4293fed8e7da4edf6b10b19f947e2c774b43c69e9e0e31c57776f9e222"
    end
  end

  on_linux do
    url "https://github.com/rkristelijn/cpm/releases/download/v0.8.0/cpm-linux-amd64.tar.gz"
    sha256 "71466f53c168a38801bff4e0ed078bdd50bdc1d16f28c4cf8cbe2d09e2f6d04e"
  end

  def install
    bin.install "cpm"
  end

  test do
    assert_match "cpm", shell_output("#{bin}/cpm help")
  end
end
