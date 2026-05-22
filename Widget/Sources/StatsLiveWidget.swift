import WidgetKit
import SwiftUI
import StatsShared

/// Stats' one widget: live CPU + memory + disk gauges. No buttons —
/// the widget is purely observational. Two sizes:
///   • small: three stacked rows with a label + thin bar + percent.
///   • medium: same gauges in a row with the top-process subline.
struct StatsLiveWidget: Widget {
    let kind: String = "StatsLiveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) {
            entry in
            StatsWidgetView(entry: entry)
                // Desktop-widget background card (required on macOS
                // 14+ — without it the widget paints over the
                // wallpaper with no card behind it and looks broken).
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Stats Live")
        .description("CPU, memory, and disk at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct StatsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsEntry

    var body: some View {
        switch family {
        case .systemSmall:  SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        default:            SmallView(entry: entry)
        }
    }
}
