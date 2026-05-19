import Foundation

/// Opt-in privileged sensor access — temperatures, fan RPM, GPU power.
/// `powermetrics` requires root, so (only when the user enables it) Stats
/// installs a narrowly-scoped passwordless-sudo rule that permits *exactly*
/// the read-only sampling command and nothing else. Disclosed + removable,
/// same consented pattern as Espresso's clamshell.
///
/// Returns nil on success or an error message string.
enum Privileged {
    static let sudoersPath = "/etc/sudoers.d/stats_metrics"

    /// The one command the rule authorises — must match what SensorsSampler runs.
    static let pmArgs = ["/usr/bin/powermetrics", "-n", "1", "-i", "200",
                         "--samplers", "smc,gpu_power", "--format", "plist"]

    private static var sudoersContent: String {
        // In a sudoers Cmnd_Alias, commas separate commands — so a literal
        // comma inside an argument (here `--samplers smc,gpu_power`) must be
        // backslash-escaped or the whole file fails to parse.
        let cmd = pmArgs.joined(separator: " ")
            .replacingOccurrences(of: ",", with: "\\,")
        return """
        Cmnd_Alias STATS_PM = \(cmd)
        %admin ALL=(ALL) NOPASSWD: STATS_PM
        """
    }

    static var enabled: Bool { FileManager.default.fileExists(atPath: sudoersPath) }

    static let disclosure = """
    To read temperatures, fan RPM and GPU power, Stats needs to run macOS's \
    `powermetrics`, which requires administrator rights.

    Enabling this installs a system rule at \(sudoersPath) that lets Stats run \
    ONLY this exact read-only command without a password each time:

        powermetrics -n 1 --samplers smc,gpu_power --format plist

    It grants nothing else, changes no settings, and you can remove it anytime \
    from Stats' Sensors panel.
    """

    static func install() -> String? {
        // Always (re)write so an outdated/broken rule self-heals on re-enable.
        let escaped = sudoersContent
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        let script = "do shell script \"printf '\(escaped)\\n' | tee \(sudoersPath) > /dev/null && chmod 440 \(sudoersPath)\" with administrator privileges"
        return runOsascript(script)
    }

    static func remove() -> String? {
        guard enabled else { return nil }
        return runOsascript("do shell script \"rm -f \(sudoersPath)\" with administrator privileges")
    }

    private static func runOsascript(_ script: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
        do { try p.run() } catch { return "osascript failed: \(error.localizedDescription)" }
        p.waitUntilExit()
        if p.terminationStatus == 0 { return nil }
        let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        if msg.contains("User canceled") || msg.contains("-128") { return "Authorization cancelled." }
        return msg.isEmpty ? "Authorization failed." : msg
    }
}
