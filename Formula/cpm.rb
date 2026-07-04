class Cpm < Formula
  desc "Code project maturity — quality layer between git and your code"
  homepage "https://github.com/rkristelijn/cpm"
  license "MIT"
  version "0.5.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rkristelijn/cpm/releases/download/v0.5.0/cpm-macos-arm64.tar.gz"
      sha256 "4fcde61c2719dd43942ef0492650a0a080f2f7d4153ef0a1f3a9d629a1be06db"
    else
      url "https://github.com/rkristelijn/cpm/releases/download/v0.5.0/cpm-macos-amd64.tar.gz"
      sha256 "4fcde61c2719dd43942ef0492650a0a080f2f7d4153ef0a1f3a9d629a1be06db"
    end
  end

  on_linux do
    url "https://github.com/rkristelijn/cpm/releases/download/v0.5.0/cpm-linux-amd64.tar.gz"
    sha256 "76ab0e4e4c48f57b40c9a522b832a80d5dd4112f5cf0377d41fed45761ebb84a"
  end

  def install
    bin.install "cpm"
  end

  test do
    assert_match "cpm", shell_output("#{bin}/cpm help")
  end
end
