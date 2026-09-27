# typed: false
# frozen_string_literal: true

class Gascity < Formula
  desc "Orchestration-builder SDK for multi-agent coding workflows"
  homepage "https://github.com/gastownhall/gascity"
  version "1.2.1"
  license "MIT"

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/gastownhall/gascity/releases/download/v1.2.1/gascity_1.2.1_linux_arm64.tar.gz"
      sha256 "305c55fe2832383264b4fb70a66af3d6af6255990c586760f8b21f01e6f043d4"
    else
      url "https://github.com/gastownhall/gascity/releases/download/v1.2.1/gascity_1.2.1_linux_amd64.tar.gz"
      sha256 "7abc26d826881d38219600e25e78a0a36802eddf9e6ed77046275f5ec9e72172"
    end
  end

  depends_on "local/factory/beads"
  depends_on "jq"
  depends_on "tmux"

  def install
    bin.install "gc"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/gc version")
  end
end
