import SwiftUI

/// Things that can be drawn directly in the menu-bar status item.
enum MenuBarWidget: String, Codable, CaseIterable, Identifiable {
    case icon, cpuText, cpuGraph, memText, memGraph, netText, netGraph, diskText
    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon: return "App icon"
        case .cpuText: return "CPU %"
        case .cpuGraph: return "CPU graph"
        case .memText: return "Memory %"
        case .memGraph: return "Memory graph"
        case .netText: return "Network ↓↑"
        case .netGraph: return "Network graph"
        case .diskText: return "Disk used %"
        }
    }
}

struct MenuBarSettings: Codable {
    var widgets: [MenuBarWidget] = [.icon]
    /// Font size for the tray metric value (CPU%, RAM%, etc.). The tag
    /// label scales proportionally. Range: 9...16 (default 11).
    var fontSize: Double = 11

    private static var url: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stats", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("menubar.json")
    }

    static func load() -> MenuBarSettings {
        (try? JSONDecoder().decode(MenuBarSettings.self, from: Data(contentsOf: url)))
            ?? MenuBarSettings()
    }

    func save() {
        if let d = try? JSONEncoder().encode(self) { try? d.write(to: Self.url) }
    }
}

/// Cheap polyline sparkline (no Charts dependency in the hot path).
struct Sparkline: Shape {
    let values: [Double]   // expected 0...1
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard values.count > 1 else { return p }
        let stepX = rect.width / CGFloat(values.count - 1)
        for (i, v) in values.enumerated() {
            let x = rect.minX + CGFloat(i) * stepX
            let y = rect.maxY - CGFloat(max(0, min(1, v))) * rect.height
            i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
        }
        return p
    }
}

/// The composite view rasterised into the status item each tick.
struct MenuBarWidgetView: View {
    let store: StatsStore

    var body: some View {
        HStack(spacing: 7) {
            ForEach(store.menuBar.widgets) { w in
                switch w {
                case .icon:
                    Image(systemName: "waveform.path.ecg").font(.system(size: 13))
                case .cpuText:
                    metric("CPU", pctStr(store.cpu.total))
                case .cpuGraph:
                    graph(store.cpuHistory.values)
                case .memText:
                    metric("RAM", pctStr(store.memory.usedFraction))
                case .memGraph:
                    graph(store.memHistory.values)
                case .netText:
                    metric("UP", rateNum(store.net.txBytesPerSec))
                    metric("DL", rateNum(store.net.rxBytesPerSec))
                case .netGraph:
                    graph(store.netHistory.values)
                case .diskText:
                    metric("DISK", pctStr(store.disk.primary?.usedFraction ?? 0))
                }
            }
        }
        .frame(height: 18)
        .padding(.horizontal, 3)
        .foregroundStyle(.white)
    }

    private func metric(_ tag: String, _ value: String) -> some View {
        let valueSize = store.menuBar.fontSize
        let tagSize = max(7, valueSize - 3)
        return HStack(spacing: 2) {
            Text(tag).font(.system(size: tagSize, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            dimZeros(value, dim: Color.white.opacity(0.45))
                .font(.system(size: valueSize, weight: .semibold, design: .monospaced))
        }
    }

    private func graph(_ vals: [Double]) -> some View {
        let recent = Array(vals.suffix(28))
        return ZStack {
            Sparkline(values: recent).fill(Color.white.opacity(0.20))
                .mask(Sparkline(values: recent).stroke(lineWidth: 14))
            Sparkline(values: recent).stroke(Color.white, lineWidth: 1.3)
        }
        .frame(width: 36, height: 14)
    }
}
