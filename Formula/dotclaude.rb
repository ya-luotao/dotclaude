# Homebrew formula for dotclaude. The release workflow rewrites the `url` and
# `sha256` lines on every tagged release; do not edit them by hand.
#
#   brew tap ya-luotao/dotclaude https://github.com/ya-luotao/dotclaude
#   brew install dotclaude
class Dotclaude < Formula
  desc "Run multiple Claude Code accounts on one machine via CLAUDE_CONFIG_DIR profiles"
  homepage "https://github.com/ya-luotao/dotclaude"
  url "https://github.com/ya-luotao/dotclaude/archive/refs/tags/v0.10.0.tar.gz"
  sha256 "e608f0a49ab361afc989f208d3ed8cd8d3ee3889553da58d0b18f3c36a863ad0"
  license "MIT"
  head "https://github.com/ya-luotao/dotclaude.git", branch: "main"

  def install
    bin.install "bin/dotclaude"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/dotclaude version")
  end
end
