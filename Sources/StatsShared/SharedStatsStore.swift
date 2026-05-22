import Foundation
import WidgetKit

/// Read/write helper for `SharedStats` in the App Group container.
///
/// The host (pane + standalone) calls `write(_:)` each sampler tick;
/// the widget extension's TimelineProvider calls `read()` to refresh.
/// Reads default to a sensible empty snapshot rather than throwing —
/// the widget renders something reasonable even on first install
/// before any tick has landed.
///
/// We also debounce widget reloads: writing more often than once per
/// `reloadInterval` skips the `WidgetCenter.reloadAllTimelines()` call
/// so the host can keep sampling at its native cadence (twice a
/// second) without spamming WidgetKit with timeline invalidations.
public enum SharedStatsStore {

    /// Single JSON file under the App Group container. Atomic writes
    /// so the widget never sees a half-written buffer mid-tick.
    private static let filename = "shared-stats.json"

    /// Minimum gap between widget timeline reloads.
    /// Twice a second is plenty for desktop widgets — WidgetKit
    /// throttles anyway, but being polite about it keeps power use
    /// sane on battery.
    private static let reloadInterval: TimeInterval = 2.0
    private static var lastReload: Date = .distantPast

    public static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(filename)
    }

    public static func write(_ stats: SharedStats) {
        guard let url = fileURL else { return }
        do {
            let data = try JSONEncoder().encode(stats)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Silent — widget will keep reading the previous file
            // until the next tick succeeds.
            return
        }
        // Throttled timeline reload (see `reloadInterval`).
        let now = Date()
        if now.timeIntervalSince(lastReload) >= reloadInterval {
            lastReload = now
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    public static func read() -> SharedStats {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let stats = try? JSONDecoder().decode(
                  SharedStats.self, from: data)
        else { return SharedStats() }
        return stats
    }
}
