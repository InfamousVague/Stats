import SwiftUI
import WidgetKit
import StatsShared

/// `.systemMedium` Stats layout: three gauges side-by-side with
/// a "TOP" line underneath showing the busiest process. Wider than
/// small so each gauge gets a full thin-bar row with its absolute
/// number ("12 GB of 32 GB") alongside.
struct MediumView: View {
    let entry: StatsEntry

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("STATS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.isStale {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("stale")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)

            VStack(spacing: 5) {
                gaugeRow(label: "CPU",
                         value: entry.stats.cpu,
                         subtitle: nil)
                gaugeRow(label: "RAM",
                         value: entry.stats.memoryUsed,
                         subtitle: memorySubtitle)
                gaugeRow(label: "Disk",
                         value: entry.stats.diskUsed,
                         subtitle: diskSubtitle)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text("TOP")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
                Text(topLine)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    private var topLine: String {
        if entry.stats.topProcessName.isEmpty { return "—" }
        return "\(entry.stats.topProcessName)"
            + " · \(fmtPct(entry.stats.topProcessCPU))"
    }

    private var memorySubtitle: String? {
        guard entry.stats.memoryTotalBytes > 0 else { return nil }
        return "\(fmtBytes(entry.stats.memoryUsedBytes)) of "
            + fmtBytes(entry.stats.memoryTotalBytes)
    }

    private var diskSubtitle: String? {
        guard entry.stats.diskTotalBytes > 0 else { return nil }
        return "\(fmtBytes(entry.stats.diskUsedBytes)) of "
            + fmtBytes(entry.stats.diskTotalBytes)
    }

    private func gaugeRow(label: String,
                          value: Double,
                          subtitle: String?) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                    Capsule()
                        .fill(tint(for: value))
                        .frame(width: geo.size.width
                               * max(0, min(1, value)))
                }
            }
            .frame(height: 6)

            VStack(alignment: .trailing, spacing: 0) {
                Text(fmtPct(value))
                    .font(.system(size: 11, weight: .semibold,
                                  design: .rounded))
                    .monospacedDigit()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
    }

    // Hardcoded tints (see SmallView for rationale — accentColor was
    // resolving to white on the widget render surface in Alfred).
    private func tint(for v: Double) -> Color {
        if v > 0.90 { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if v > 0.70 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 1.00, green: 0.49, blue: 0.55)
    }
}
