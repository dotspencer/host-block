import Foundation

enum HelperError: LocalizedError {
    case installCancelled
    case installFailed(String)
    case notAuthorized
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .installCancelled:
            return "Setup was cancelled before HostBlock could be authorized."
        case .installFailed(let message):
            return "Helper installation failed: \(message)"
        case .notAuthorized:
            return "HostBlock isn't authorized to edit the hosts file. Choose Finish Setup from the menu."
        case .commandFailed(let message):
            return message.isEmpty ? "The HostBlock helper command failed." : message
        }
    }
}

/// A tiny root-owned shell helper installed once (single admin prompt) to
/// /Library/PrivilegedHelperTools, authorized via /etc/sudoers.d so every later
/// hosts-file update and DNS flush runs without prompting again.
struct PrivilegedHelper {
    static let helperPath = "/Library/PrivilegedHelperTools/com.hostblock.helper"
    static let sudoersPath = "/etc/sudoers.d/hostblock"

    var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: Self.helperPath)
    }

    // MARK: Commands

    func apply(stagingFile: URL) async throws {
        try await run(["apply", stagingFile.path])
    }

    func removeBlock() async throws {
        try await run(["remove"])
    }

    func flushDNS() async throws {
        try await run(["flush"])
    }

    private func run(_ args: [String]) async throws {
        guard isInstalled else { throw HelperError.notAuthorized }
        do {
            try await runProcess("/usr/bin/sudo", ["-n", Self.helperPath] + args)
        } catch HelperError.commandFailed(let message) {
            if message.contains("password is required") || message.contains("a terminal is required") {
                throw HelperError.notAuthorized
            }
            throw HelperError.commandFailed(message)
        }
    }

    // MARK: Installation (the one-time admin prompt)

    func install() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("hostblock-setup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let helperURL = tmpDir.appendingPathComponent("com.hostblock.helper")
        let installerURL = tmpDir.appendingPathComponent("install.sh")
        try Self.helperScript.write(to: helperURL, atomically: true, encoding: .utf8)
        try Self.installerScript.write(to: installerURL, atomically: true, encoding: .utf8)

        let command = "/bin/bash \(Self.shellQuote(installerURL.path)) \(Self.shellQuote(helperURL.path))"
        let prompt = "HostBlock needs administrator access to manage the hosts file. You will only be asked this once."
        let appleScript =
            "do shell script \"\(Self.appleScriptEscape(command))\" with administrator privileges with prompt \"\(Self.appleScriptEscape(prompt))\""

        do {
            try await runProcess("/usr/bin/osascript", ["-e", appleScript])
        } catch HelperError.commandFailed(let message) {
            if message.contains("-128") || message.lowercased().contains("cancel") {
                throw HelperError.installCancelled
            }
            throw HelperError.installFailed(message)
        }
    }

    // MARK: Process plumbing

    private func runProcess(_ executable: String, _ arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = Pipe()
            process.terminationHandler = { finished in
                let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if finished.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HelperError.commandFailed(stderr))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: Scripts

    /// Runs as root once, via the admin prompt. Installs the helper and a sudoers
    /// rule scoped to exactly that root-owned helper binary.
    static let installerScript = #"""
    #!/bin/bash
    set -euo pipefail
    SRC="${1:?usage: install.sh <helper source path>}"
    DEST="/Library/PrivilegedHelperTools/com.hostblock.helper"

    mkdir -p /Library/PrivilegedHelperTools
    cp "$SRC" "$DEST"
    chown root:wheel "$DEST"
    chmod 755 "$DEST"

    printf 'ALL ALL=(root) NOPASSWD: %s\n' "$DEST" > /etc/sudoers.d/hostblock
    chown root:wheel /etc/sudoers.d/hostblock
    chmod 440 /etc/sudoers.d/hostblock
    """#

    /// The privileged helper itself. Only ever writes strictly validated
    /// "0.0.0.0 domain" lines between the HostBlock markers in /etc/hosts.
    static let helperScript = #"""
    #!/bin/bash
    # HostBlock privileged helper v1 — manages the HostBlock section of /etc/hosts.
    set -euo pipefail

    HOSTS="/etc/hosts"
    START_MARK="#HOSTBLOCK_START"
    END_MARK="#HOSTBLOCK_END"

    strip_block() {
      awk -v s="$START_MARK" -v e="$END_MARK" '
        $0 == s { inside = 1; next }
        $0 == e { inside = 0; next }
        !inside { print }
      ' "$HOSTS"
    }

    write_hosts() {
      local tmp
      tmp=$(mktemp "/etc/hosts.hostblock.XXXXXX")
      cat > "$tmp"
      chown root:wheel "$tmp"
      chmod 644 "$tmp"
      mv -f "$tmp" "$HOSTS"
    }

    flush_dns() {
      dscacheutil -flushcache 2>/dev/null || true
      killall -HUP mDNSResponder 2>/dev/null || true
    }

    case "${1:-}" in
      apply)
        src="${2:?usage: com.hostblock.helper apply <domains file>}"
        {
          strip_block
          echo "$START_MARK"
          grep -E '^0\.0\.0\.0 [a-z0-9_][a-z0-9._-]*$' "$src" || true
          echo "$END_MARK"
        } | write_hosts
        flush_dns
        ;;
      remove)
        strip_block | write_hosts
        flush_dns
        ;;
      flush)
        flush_dns
        ;;
      version)
        echo "1"
        ;;
      *)
        echo "com.hostblock.helper: unknown command '${1:-}'" >&2
        exit 64
        ;;
    esac
    """#
}
