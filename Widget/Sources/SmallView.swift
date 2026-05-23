import SwiftUI
import WidgetKit
import StatsShared

/// `.systemSmall` Stats layout — three circular ring gauges
/// (CPU / RAM / Disk) with sparklines, plus the tracked "STATS"
/// caps brand line at the top. No network/topprocess here; small
/// is the headline-only tile, the medium/large variants surface the
/// rest. Mirrors Apple's Battery widget vibe — multiple round gauges
/// reading as a glance dashboard.
struct SmallView: View {
    let entry: StatsEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("STATS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    // Tints into the user's accent in Tinted/Clear
                    // appearance modes; left alone in Default mode.
                    .widgetAccentable()
                Spacer()
                if entry.isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                gauge("CPU", entry.stats.cpu, entry.stats.cpuHistory)
                gauge("RAM", entry.stats.memoryUsed, entry.stats.memHistory)
                gauge("DISK", entry.stats.diskUsed, entry.stats.diskHistory)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Small is the easiest tile to over-pad (only 3 gauges in
        // a narrow tile), but 12 was still leaving the rings looking
        // edge-stuck on retina; 14 gives a touch more breathing
        // room without forcing the rings to shrink.
        .padding(14)
    }

    private func gauge(_ label: String,
                       _ value: Double,
                       _ history: [Double]) -> some View {
        CircularGauge(
            label: label,
            value: value,
            history: history,
            tint: tint(for: value),
            size: 48
        )
        .frame(maxWidth: .infinity)
    }

    // Same band thresholds the previous bar-style gauges used —
    // pink under normal load, amber over 70%, red over 90%.
    private func tint(for v: Double) -> Color {
        if v > 0.90 { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if v > 0.70 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 1.00, green: 0.49, blue: 0.55)
    }
}
