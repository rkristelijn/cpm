class Cpm < Formula
  desc "Code project maturity — quality layer between git and your code"
  homepage "https://github.com/rkristelijn/cpm"
  license "MIT"
  version "0.4.2"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/rkristelijn/cpm/releases/download/v0.4.2/cpm-macos-arm64.tar.gz"
      sha256 "eaed7aa63c4fa01a75522267efa25195fff953458f421e2c1c813b2dc6c4a70e"
    else
      url "https://github.com/rkristelijn/cpm/releases/download/v0.4.2/cpm-macos-amd64.tar.gz"
      sha256 "68f9cb90525ed1bb29e7c24b18bca0b7d24975191c4a05c81f3032ce90265e38"
    end
  end

  on_linux do
    url "https://github.com/rkristelijn/cpm/releases/download/v0.4.2/cpm-linux-amd64.tar.gz"
    sha256 "32500f75951a5a8b8d2b0d05755feb42547d8e366c09a2cab125330435b9ce90"
  end

  def install
    bin.install "cpm"
  end

  test do
    assert_match "cpm", shell_output("#{bin}/cpm help")
  end
end
