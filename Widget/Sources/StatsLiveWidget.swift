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
                // `Color("WidgetBackground")` from the asset catalog.
                // The macOS Tahoe WindowServer swaps this named
                // surface for its Liquid Glass plate when the widget
                // is on the desktop — that's where the translucent
                // edge feathering + specular highlight + shadow come
                // from, NOT from a Material or `.fill.tertiary`. See
                // the deep-dive comment in Alfred's widget config and
                // the `WidgetKit-Implementing-Liquid-Glass-Design`
                // doc Apple ships with Xcode 26.
                .containerBackground(for: .widget) {
                    Color("WidgetBackground")
                }
        }
        .configurationDisplayName("Stats Live")
        .description("CPU, memory, disk, and network — rings, sparklines, and the busiest process.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct StatsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatsEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  SmallView(entry: entry)
            case .systemMedium: MediumView(entry: entry)
            case .systemLarge:  LargeView(entry: entry)
            default:            SmallView(entry: entry)
            }
        }
        // Desktop-widget tap → MattsSoftware launcher's
        // application(_:open:) routes to the Stats pane and
        // shows the popover. Without this hook the tap launches
        // Stats' standalone bundle id, SuiteGuard exits in
        // merged mode, nothing visible happens.
        .widgetURL(URL(string: "mattssoftware://stats"))
    }
}
