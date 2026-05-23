import SwiftUI
import Charts

/// Apple-Battery-style circular ring gauge with a sparkline of the
/// metric's recent history inside the ring and the current value
/// underneath. Used as the building block for the new Stats widget
/// layouts (Small / Medium / Large) — each metric (CPU / RAM / Disk
/// / Net) renders as one of these.
///
/// • Background ring: muted secondary stroke at a fixed width.
/// • Foreground ring: tinted, trimmed to `value` (0…1), rotated so 0
///   starts at 12 o'clock and increases clockwise.
/// • Centre stack: label caps → sparkline of `history` → big numeric
///   value. All three scale with `size` so the gauge stays legible
///   from 44 pt (small tile, 3 across) up to 90 pt (large tile).
///
/// `history` is fed by `SharedStats.cpuHistory` etc. — fixed-capacity
/// rings the host writes every ~4.5 s. Two-or-fewer points falls back
/// to a centred dot so the gauge still feels alive on first install.
struct CircularGauge: View {
    let label: String
    let value: Double
    let history: [Double]
    let valueText: String?      // nil → defaults to "NN%"
    let tint: Color
    let size: CGFloat

    init(
        label: String,
        value: Double,
        history: [Double],
        valueText: String? = nil,
        tint: Color,
        size: CGFloat
    ) {
        self.label = label
        self.value = value
        self.history = history
        self.valueText = valueText
        self.tint = tint
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.20),
                        lineWidth: ringWidth)
            Circle()
                // Tiny floor so an exact-zero value still shows the
                // round-cap dot — otherwise the gauge looks broken
                // on a freshly booted system.
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(tint,
                        style: StrokeStyle(lineWidth: ringWidth,
                                           lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: size * 0.04) {
                Text(label)
                    .font(.system(size: size * 0.13, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Need at least two points for a line; below that we
                // just hold the vertical space so layout is stable.
                if history.count >= 2 {
                    Sparkline(values: history, tint: tint)
                        .frame(height: size * 0.20)
                        .padding(.horizontal, size * 0.18)
                } else {
                    Color.clear.frame(height: size * 0.20)
                }

                Text(valueText ?? fmtPct(value))
                    .font(.system(size: size * 0.20,
                                  weight: .bold,
                                  design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(.horizontal, size * 0.15)
        }
        .frame(width: size, height: size)
    }

    private var ringWidth: CGFloat {
        // Apple Battery widget uses ~10% of diameter as ring width.
        max(3, size * 0.08)
    }
}

/// Bare-bones SwiftUI Charts sparkline. No axes, no labels, no
/// background — just a tinted line on transparent. Domain pinned to
/// 0…1 (CPU/mem/disk/net history is already normalised host-side).
struct Sparkline: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { i, v in
            LineMark(x: .value("t", i), y: .value("v", v))
                .foregroundStyle(tint)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5,
                                       lineCap: .round))
        }
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(Color.clear) }
    }
}
