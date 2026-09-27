class Beads < Formula
  desc "Memory upgrade for your coding agent"
  homepage "https://github.com/steveyegge/beads"
  url "https://github.com/steveyegge/beads/archive/refs/tags/v1.0.5.tar.gz"
  sha256 "06e52a953b2e46044c70bc41421554c5d006370b1a25905b752d02eb0b337f0d"
  license "MIT"
  compatibility_version 1

  depends_on "go" => :build
  depends_on "local/factory/dolt"
  depends_on "icu4c@78"

  def install
    if OS.linux? && Hardware::CPU.arm64?
      ENV["CGO_ENABLED"] = "1"
      ENV["GO_EXTLINK_ENABLED"] = "1"
      ENV.append "GOFLAGS", "-buildmode=pie"
    end
    ldflags = %W[-s -w -X main.Version=#{version} -X main.Build=portable-bootstrap -X main.Branch=v#{version}]
    system "go", "build", *std_go_args(ldflags:), "./cmd/bd"
    bin.install_symlink "beads" => "bd"
    generate_completions_from_executable(bin/"bd", shell_parameter_format: :cobra)
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bd --version")
  end
end
