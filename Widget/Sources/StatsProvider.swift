import WidgetKit
import StatsShared

/// One snapshot the widget will render.
struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: SharedStats
    /// True when the host hasn't ticked in a while — the widget
    /// uses this to mute the gauges and surface a "no data" hint
    /// so the user can tell the live numbers aren't trustworthy.
    var isStale: Bool { Date().timeIntervalSince(stats.sampledAt) > 10 }
}

/// Timeline provider that reads SharedStats every minute from the
/// App Group container. We don't need a high refresh rate from
/// WidgetKit itself — the *host* calls `WidgetCenter.reloadAll-
/// Timelines()` whenever it writes new samples, which is what
/// actually drives sub-second updates. The 60s entries here are
/// just a safety net so the widget doesn't go totally stale if the
/// host is killed.
struct StatsProvider: TimelineProvider {

    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: .now, stats: SharedStats())
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (StatsEntry) -> Void) {
        completion(StatsEntry(date: .now, stats: SharedStatsStore.read()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<StatsEntry>) -> Void)
    {
        let stats = SharedStatsStore.read()
        let entry = StatsEntry(date: .now, stats: stats)
        // Refresh at the top of the next minute. Host writes will
        // invalidate the timeline earlier whenever new samples land.
        let nextRefresh = Date().addingTimeInterval(60)
        completion(Timeline(entries: [entry],
                            policy: .after(nextRefresh)))
    }
}
