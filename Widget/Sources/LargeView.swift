import SwiftUI
import WidgetKit
import Charts
import StatsShared

/// `.systemLarge` Stats — full-fat dashboard. Four bigger gauges
/// across the top, a tall CPU sparkline below (the chart the user
/// will be staring at most), then the data-density extras: split
/// network down / up with bytes/sec, memory used-of-total subtitle,
/// and the top process line. Designed for a user who actually places
/// the large tile and wants real numbers, not just a vibe-check.
struct LargeView: View {
    let entry: StatsEntry

    var body: some View {
        VStack(spacing: 10) {
            // ── Brand row.
            HStack(spacing: 6) {
                Text("STATS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
                Spacer()
                Text(fmtRelative(entry.stats.sampledAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                if entry.isStale {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("stale")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                }
            }

            // ── Four ring gauges across.
            HStack(spacing: 6) {
                gauge("CPU",
                      value: entry.stats.cpu,
                      history: entry.stats.cpuHistory,
                      tint: usageTint(entry.stats.cpu))
                gauge("RAM",
                      value: entry.stats.memoryUsed,
                      history: entry.stats.memHistory,
                      tint: usageTint(entry.stats.memoryUsed))
                gauge("DISK",
                      value: entry.stats.diskUsed,
                      history: entry.stats.diskHistory,
                      tint: usageTint(entry.stats.diskUsed))
                gauge("NET",
                      value: clampUnit(combinedNet),
                      history: entry.stats.netHistory,
                      tint: netTint,
                      valueText: fmtRate(combinedNetBytes))
            }

            // ── Larger CPU sparkline — primary "trend" chart.
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CPU · last ~4.5 min")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(fmtPct(entry.stats.cpu))
                        .font(.system(size: 11, weight: .semibold,
                                      design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                bigChart(history: entry.stats.cpuHistory,
                         tint: usageTint(entry.stats.cpu))
                    .frame(height: 44)
            }

            // ── Data-density extras: top process + memory subtitle
            // + network down / up split (one line each so the user
            // can pull the number they need at a glance).
            VStack(alignment: .leading, spacing: 4) {
                statRow(
                    icon: "cpu",
                    label: "TOP",
                    value: topLine
                )
                if let m = memSubtitle {
                    statRow(
                        icon: "memorychip",
                        label: "MEM",
                        value: m
                    )
                }
                statRow(
                    icon: "arrow.down",
                    label: "DOWN",
                    value: fmtRate(entry.stats.networkDownBytesPerSec)
                )
                statRow(
                    icon: "arrow.up",
                    label: "UP",
                    value: fmtRate(entry.stats.networkUpBytesPerSec)
                )
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Large tile is dense by design — bump padding from the
        // family default (12) to 18 so the gauge ring tops, the
        // section footers, and the wallpaper edge all get visible
        // breathing room. The earlier 14 left the ring tops kissing
        // the brand row and the UP row kissing the bottom edge.
        .padding(18)
    }

    // MARK: subviews

    private func gauge(_ label: String,
                       value: Double,
                       history: [Double],
                       tint: Color,
                       valueText: String? = nil) -> some View {
        CircularGauge(
            label: label,
            value: value,
            history: history,
            valueText: valueText,
            tint: tint,
            size: 78
        )
        .frame(maxWidth: .infinity)
    }

    private func bigChart(history: [Double], tint: Color) -> some View {
        Chart(Array(history.enumerated()), id: \.offset) { i, v in
            AreaMark(x: .value("t", i), y: .value("v", v))
                .foregroundStyle(tint.opacity(0.25))
            LineMark(x: .value("t", i), y: .value("v", v))
                .foregroundStyle(tint)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    private func statRow(icon: String,
                         label: String,
                         value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 12)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
    }

    // MARK: derived

    private var topLine: String {
        if entry.stats.topProcessName.isEmpty { return "—" }
        return "\(entry.stats.topProcessName)"
            + " · \(fmtPct(entry.stats.topProcessCPU))"
    }

    private var memSubtitle: String? {
        guard entry.stats.memoryTotalBytes > 0 else { return nil }
        return "\(fmtBytes(entry.stats.memoryUsedBytes)) of "
            + fmtBytes(entry.stats.memoryTotalBytes)
    }

    private var combinedNetBytes: Double {
        entry.stats.networkDownBytesPerSec
            + entry.stats.networkUpBytesPerSec
    }
    private var combinedNet: Double { combinedNetBytes / 5_000_000 }

    private func clampUnit(_ v: Double) -> Double {
        max(0, min(1, v))
    }

    private func usageTint(_ v: Double) -> Color {
        if v > 0.90 { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if v > 0.70 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 1.00, green: 0.49, blue: 0.55)
    }
    private var netTint: Color {
        Color(red: 0.40, green: 0.78, blue: 0.95)
    }

    /// Human-readable "last sampled" — small enough to live in the
    /// header without dominating.
    private func fmtRelative(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: Date())
    }
}
