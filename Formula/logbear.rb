# Rendered by scripts/render-formula.sh. Every release writes the result to the tap, so edit
# this template rather than the tap's copy, which the next release overwrites.
class Logbear < Formula
  desc "Wrap a command, capture everything it emits, and push errors at your agent"
  homepage "https://logbear.sh"
  license "MIT"

  depends_on :macos

  on_macos do
    on_arm do
      url "https://github.com/teralabx/logbear/releases/download/v0.1.0/logbear-0.1.0-aarch64-apple-darwin.tar.gz"
      sha256 "ae2754da3c0f0a523367579f620f01ef8750a62a50f1735d15e7bcffebcc374e"
    end
    on_intel do
      url "https://github.com/teralabx/logbear/releases/download/v0.1.0/logbear-0.1.0-x86_64-apple-darwin.tar.gz"
      sha256 "e9f03c030564beadb9cee137382b12120af02be0be5d9fcf35ed74c351c30d09"
    end
  end

  def install
    bin.install "logbear", "logbeard", "logbear-mcp", "logbear-hook"
  end

  service do
    run [opt_bin/"logbeard", "serve"]
    # Not a bare `keep_alive true`: the daemon exits 0 both when asked to stop and when it
    # finds another instance (the desktop app's) already holding the lock, and relaunching
    # it then is a respawn loop. Crashes exit non-zero and are still restarted, and so is a
    # daemon stepping aside for an upgrade, which is how `brew upgrade` takes effect.
    keep_alive successful_exit: false
    log_path var/"log/logbear/logbeard.log"
    error_log_path var/"log/logbear/logbeard.log"
  end

  def caveats
    <<~EOS
      Start the daemon so runs are captured across reboots:
        brew services start logbear

      Connect your coding agents (Claude Code, Codex, pi, Hermes) — it shows what it
      will change and asks first:
        logbear setup

      The desktop app is a separate download from https://logbear.sh — this formula
      installs the CLI, the daemon, the MCP server and the hook only.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/logbear --version")

    # A wrapped command must reproduce its child's output byte for byte and
    # propagate the exit code, with no daemon running.
    ENV["LOGBEAR_HOME"] = testpath/"home"
    assert_equal "hello", shell_output("#{bin}/logbear /bin/sh -c 'printf hello'")
    shell_output("#{bin}/logbear /bin/sh -c 'exit 7'", 7)

    # The MCP server must speak JSON-RPC on stdio.
    handshake = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"brew-test","version":"1"}}}
    JSON
    assert_match "protocolVersion",
                 pipe_output(bin/"logbear-mcp", handshake, 0)
  end
end
