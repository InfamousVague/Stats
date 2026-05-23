import SwiftUI
import WidgetKit
import StatsShared

/// `.systemMedium` Stats — four gauges (CPU / RAM / Disk / Net) in
/// a row, plus the top-process + memory subtitle line stacked
/// beneath. Wider than small so we have room for the full set of
/// metrics; the Large family will scale them up further and add the
/// network down/up split.
struct MediumView: View {
    let entry: StatsEntry

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("STATS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
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

            HStack(spacing: 4) {
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
                      // Net values aren't a usage ratio — re-use the
                      // host's normalised history (0…1 against a 5
                      // MB/s soft ceiling) for the ring's fill so the
                      // sparkline shape matches the ring level. Show
                      // the actual throughput in the centre label.
                      value: clampUnit(currentNet),
                      history: entry.stats.netHistory,
                      tint: netTint,
                      valueText: fmtRate(currentNetBytes))
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
                if let m = memSubtitle {
                    Text(m)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Medium runs four gauges + a TOP/MEM row, so the family
        // default 12pt padding crammed the rings against the brand
        // row. 16pt gives the gauges a bit of headroom while
        // keeping the row balance Apple-Battery-style.
        .padding(16)
    }

    // MARK: derived bits

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

    /// Combined down+up bytes/sec, for the net gauge centre label.
    private var currentNetBytes: Double {
        entry.stats.networkDownBytesPerSec
            + entry.stats.networkUpBytesPerSec
    }

    /// Same normalisation the host uses for `netHistory` so the ring
    /// fill agrees with the sparkline shape (1.0 at 5 MB/s).
    private var currentNet: Double {
        currentNetBytes / 5_000_000
    }

    // MARK: helpers

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
            size: 64
        )
        .frame(maxWidth: .infinity)
    }

    private func clampUnit(_ v: Double) -> Double {
        max(0, min(1, v))
    }

    /// Same colour band as the bar gauges: pink → amber → red.
    private func usageTint(_ v: Double) -> Color {
        if v > 0.90 { return Color(red: 0.95, green: 0.35, blue: 0.35) }
        if v > 0.70 { return Color(red: 0.95, green: 0.70, blue: 0.30) }
        return Color(red: 1.00, green: 0.49, blue: 0.55)
    }

    /// Network gets a distinct hue (cyan) so it doesn't blend with
    /// the three usage rings to its left.
    private var netTint: Color {
        Color(red: 0.40, green: 0.78, blue: 0.95)
    }
}
