import Foundation

/// Compact byte formatter. Used for memory + disk subtitles.
/// .file style → "12 GB" / "237 MB" — matches what macOS itself
/// shows in About → Storage.
func fmtBytes(_ n: UInt64) -> String {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useMB, .useGB, .useTB]
    f.countStyle = .file
    return f.string(fromByteCount: Int64(n))
}

/// Compact rate formatter for network. Adds "/s" suffix.
func fmtRate(_ n: Double) -> String {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useKB, .useMB, .useGB]
    f.countStyle = .file
    return f.string(fromByteCount: Int64(n)) + "/s"
}

/// Integer percent for the gauges. 0.834 → "83%".
func fmtPct(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}
