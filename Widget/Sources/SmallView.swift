import SwiftUI
import WidgetKit
import StatsShared

/// `.systemSmall` Stats layout: brand row at top, three labelled
/// horizontal-bar gauges (CPU / RAM / Disk) stacked vertically.
/// Centred on the tile; no buttons since Stats is observational.
struct SmallView: View {
    let entry: StatsEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("STATS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 7) {
                gaugeRow(label: "CPU",
                         value: entry.stats.cpu,
                         tint: cpuTint(entry.stats.cpu))
                gaugeRow(label: "RAM",
                         value: entry.stats.memoryUsed,
                         tint: memTint(entry.stats.memoryUsed))
                gaugeRow(label: "Disk",
                         value: entry.stats.diskUsed,
                         tint: diskTint(entry.stats.diskUsed))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    private func gaugeRow(label: String,
                          value: Double,
                          tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(fmtPct(value))
                    .font(.system(size: 11, weight: .semibold,
                                  design: .rounded))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width
                               * max(0, min(1, value)))
                }
            }
            .frame(height: 5)
        }
    }

    // Hardcoded tints. Color.accentColor was washing out to white on
    // the desktop widget surface in earlier Alfred testing — sticking
    // to explicit RGB so the gauges keep their meaning regardless of
    // the system accent or widget render mode.
    private func cpuTint(_ v: Double) -> Color {
        if v > 0.85 { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if v > 0.60 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 1.00, green: 0.49, blue: 0.55)  // stats pink
    }
    private func memTint(_ v: Double) -> Color {
        if v > 0.90 { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if v > 0.70 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 1.00, green: 0.49, blue: 0.55)
    }
    private func diskTint(_ v: Double) -> Color {
        if v > 0.90 { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if v > 0.80 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 1.00, green: 0.49, blue: 0.55)
    }
}
