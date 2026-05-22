import Foundation

/// Compact, widget-friendly snapshot of the system state. Written by
/// the host on every sampler tick (the pane's `tick()` method) and
/// read by the widget's timeline provider for the next refresh.
///
/// Kept deliberately small — only what the widget actually renders.
/// Adding new fields is cheap (Codable round-trips and the defaults
/// in `init` keep older readers working), but every byte here gets
/// re-serialised twice a second so don't pile on.
public struct SharedStats: Codable, Sendable, Equatable {
    /// CPU utilisation 0...1 (system-wide aggregate, the same value
    /// the menu-bar widget surfaces).
    public var cpu: Double
    /// Memory used / total, 0...1. "Used" matches the pane's "App +
    /// Wired + Compressed" definition (the figure Activity Monitor
    /// surfaces as "Memory used"); free + cached are excluded.
    public var memoryUsed: Double
    /// Bytes for the headline memory subline ("12.4 GB of 32 GB").
    public var memoryUsedBytes: UInt64
    public var memoryTotalBytes: UInt64
    /// Disk used / total for the boot volume, 0...1. Per-volume
    /// breakdown stays in the pane; the widget only needs the
    /// headline gauge.
    public var diskUsed: Double
    public var diskUsedBytes: UInt64
    public var diskTotalBytes: UInt64
    /// Display-name of the busiest process by CPU at the moment of
    /// the snapshot. Empty when no process is "busy enough" to
    /// surface — keeps the medium tile from flickering between
    /// background daemons.
    public var topProcessName: String
    public var topProcessCPU: Double
    /// Network throughput, bytes/sec. Reported as Double because the
    /// pane's NetSampler exposes a smoothed rate not a raw counter.
    public var networkDownBytesPerSec: Double
    public var networkUpBytesPerSec: Double
    /// Snapshot time. Widget surface uses this to decide between
    /// "live" and "stale" rendering — if the timeline gets backed
    /// up and our snapshot is older than ~10s the widget badges it
    /// so the user knows the numbers may have drifted.
    public var sampledAt: Date

    public init(
        cpu: Double = 0,
        memoryUsed: Double = 0,
        memoryUsedBytes: UInt64 = 0,
        memoryTotalBytes: UInt64 = 0,
        diskUsed: Double = 0,
        diskUsedBytes: UInt64 = 0,
        diskTotalBytes: UInt64 = 0,
        topProcessName: String = "",
        topProcessCPU: Double = 0,
        networkDownBytesPerSec: Double = 0,
        networkUpBytesPerSec: Double = 0,
        sampledAt: Date = .distantPast
    ) {
        self.cpu = cpu
        self.memoryUsed = memoryUsed
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.diskUsed = diskUsed
        self.diskUsedBytes = diskUsedBytes
        self.diskTotalBytes = diskTotalBytes
        self.topProcessName = topProcessName
        self.topProcessCPU = topProcessCPU
        self.networkDownBytesPerSec = networkDownBytesPerSec
        self.networkUpBytesPerSec = networkUpBytesPerSec
        self.sampledAt = sampledAt
    }
}
