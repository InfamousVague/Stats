import SwiftUI
import Charts
import AppKit

private let accent = Color(red: 0.486, green: 0.514, blue: 1.0) // #7C83FF

struct ContentView: View {
    @Environment(StatsStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: 46)
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    cpuCard
                    memoryCard
                    diskCard
                    netCard
                    powerCard
                    sensorsCard
                    topProcsCard
                    menuBarCard
                }
                .padding(14)
            }
            Divider()
            footer
                .frame(height: 46)
        }
        .frame(width: 340, height: 540)
        .tint(accent)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg").foregroundStyle(accent)
            Text("STATS").font(.system(size: 13, weight: .semibold)).tracking(3)
            Spacer()
            Text(store.info.model).font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: CPU

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("CPU", systemImage: "cpu").font(.system(size: 12, weight: .semibold))
                Spacer()
                dimZeros(pctStr(store.cpu.total))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
            }
            Chart(Array(store.cpuHistory.values.enumerated()), id: \.offset) { i, v in
                AreaMark(x: .value("t", i), y: .value("cpu", v))
                    .foregroundStyle(accent.opacity(0.25))
                LineMark(x: .value("t", i), y: .value("cpu", v))
                    .foregroundStyle(accent)
            }
            .chartYScale(domain: 0...1)
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 56)

            let p = store.cpu.perfAverage(store.info.perfCores)
            let e = store.cpu.effAverage(perf: store.info.perfCores)
            HStack(spacing: 12) {
                clusterBar(store.info.perfName, store.info.perfCores, p)
                clusterBar(store.info.effName, store.info.effCores, e)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("load").font(.system(size: 9)).foregroundStyle(.secondary)
                    Text(String(format: "%.1f %.1f %.1f",
                                store.cpu.loadAverage.0, store.cpu.loadAverage.1,
                                store.cpu.loadAverage.2))
                        .font(.system(size: 10, design: .monospaced))
                }
            }
            // per-core grid
            HStack(spacing: 3) {
                ForEach(Array(store.cpu.perCore.enumerated()), id: \.offset) { idx, v in
                    let isPerf = idx < store.info.perfCores
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(isPerf ? accent : accent.opacity(0.55))
                                .frame(height: max(2, geo.size.height * v))
                        }
                    }
                    .frame(height: 28)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            }
        }
        .padding(14).background(card)
    }

    private func clusterBar(_ name: String, _ cores: Int, _ v: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(name) ·\(cores)").font(.system(size: 9)).foregroundStyle(.secondary)
            ProgressView(value: v).tint(accent).frame(width: 90)
            dimZeros(pctStr(v)).font(.system(size: 10, design: .monospaced))
        }
    }

    // MARK: Memory

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(store.memory.pressure.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(pressureColor.opacity(0.2))
                    .foregroundStyle(pressureColor)
                    .clipShape(Capsule())
                (dimZeros(fmtBytes(store.memory.used)) + Text(" / ")
                    + dimZeros(fmtBytes(store.memory.total)))
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(accent)
            }
            GeometryReader { geo in
                HStack(spacing: 1) {
                    seg(geo, store.memory.wired, .orange)
                    seg(geo, store.memory.compressed, .purple)
                    seg(geo, store.memory.anonymous, accent)
                    seg(geo, store.memory.fileBacked, .teal)
                    seg(geo, store.memory.free, Color.white.opacity(0.08))
                }
            }
            .frame(height: 14).clipShape(RoundedRectangle(cornerRadius: 3))
            HStack(spacing: 10) {
                legend("Wired", .orange, store.memory.wired)
                legend("Compressed", .purple, store.memory.compressed)
                legend("App", accent, store.memory.anonymous)
                legend("Cached", .teal, store.memory.fileBacked)
            }
            if store.memory.swapUsed > 0 {
                Text("Swap ") + dimZeros(fmtBytes(store.memory.swapUsed)) + Text(" / ")
                    + dimZeros(fmtBytes(store.memory.swapTotal))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(14).background(card)
    }

    private func seg(_ geo: GeometryProxy, _ bytes: UInt64, _ color: Color) -> some View {
        let frac = store.memory.total > 0 ? Double(bytes) / Double(store.memory.total) : 0
        return Rectangle().fill(color).frame(width: max(0, geo.size.width * frac))
    }

    private func legend(_ name: String, _ color: Color, _ bytes: UInt64) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(name) \(fmtBytes(bytes))").font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private var pressureColor: Color {
        switch store.memory.pressure {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }

    // MARK: Disk

    private var diskCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Disk", systemImage: "internaldrive")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                (Text("R ") + dimZeros(fmtRate(store.disk.readBytesPerSec))
                    + Text("  W ") + dimZeros(fmtRate(store.disk.writeBytesPerSec)))
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(accent)
            }
            ForEach(store.disk.volumes.prefix(3)) { v in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(v.name).font(.system(size: 11))
                        Spacer()
                        (dimZeros(fmtBytes(v.used)) + Text(" / ")
                            + dimZeros(fmtBytes(v.total)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: v.usedFraction).tint(accent)
                }
            }
            if store.alfredInstalled {
                Button { store.openScheme("alfred") } label: {
                    Label("Reclaim space in Alfred", systemImage: "arrow.up.right.square")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(accent)
            }
        }
        .padding(14).background(card)
    }

    // MARK: Network

    private var netCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Network", systemImage: "network")
                .font(.system(size: 12, weight: .semibold))
            HStack(spacing: 22) {
                netStat("UP", store.net.txBytesPerSec)
                netStat("DL", store.net.rxBytesPerSec)
                Spacer()
            }
            if store.portInstalled || store.blipInstalled {
                HStack(spacing: 14) {
                    if store.portInstalled {
                        Button { store.openScheme("port") } label: {
                            Label("Ports in Port", systemImage: "arrow.up.right.square")
                                .font(.system(size: 10))
                        }.buttonStyle(.plain).foregroundStyle(accent)
                    }
                    if store.blipInstalled {
                        Button { store.openScheme("blip") } label: {
                            Label("Inspect in Blip", systemImage: "arrow.up.right.square")
                                .font(.system(size: 10))
                        }.buttonStyle(.plain).foregroundStyle(accent)
                    }
                }
            }
        }
        .padding(14).background(card)
    }

    private func netStat(_ label: String, _ bps: Double) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            dimZeros(rateNum(bps))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
        }
    }

    // MARK: Power

    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Power", systemImage: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Thermal: \(store.power.thermal)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if store.power.hasBattery {
                HStack {
                    dimZeros(pctStr(store.power.percent))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                    Text(store.power.charging ? "Charging"
                         : store.power.onAC ? "On AC" : "On battery")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    if store.power.minutesRemaining > 0 {
                        Text("\(store.power.minutesRemaining / 60)h \(store.power.minutesRemaining % 60)m")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 16) {
                    Text("Cycles: \(store.power.cycleCount)")
                    if store.power.healthPercent > 0 {
                        Text("Health: ") + dimZeros(pctStr(store.power.healthPercent))
                    }
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text("Desktop — running on AC power")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(14).background(card)
    }

    // MARK: Top processes

    private var topProcsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top processes").font(.system(size: 12, weight: .semibold))
            HStack(alignment: .top, spacing: 16) {
                procList("By memory", store.topByMemory) { fmtBytes($0.memory) }
                procList("By CPU", store.topByCPU) { String(format: "%03.0f%%", $0.cpu * 100) }
            }
        }
        .padding(14).background(card)
    }

    private func procList(_ title: String, _ procs: [ProcInfo],
                          _ value: @escaping (ProcInfo) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            ForEach(procs.prefix(6)) { p in
                HStack {
                    Text(p.name).font(.system(size: 10)).lineLimit(1)
                    Spacer()
                    dimZeros(value(p)).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Sensors (privileged)

    private var sensorsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sensors", systemImage: "thermometer.medium")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { store.sensorsEnabled },
                    set: { requestSensors($0) }
                ))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            if !store.sensorsEnabled {
                Text("Temperatures, fan RPM and GPU power need a one-time, scoped admin rule. Off by default.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            } else if !store.sensors.available {
                Text("Reading sensors…").font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 18) {
                    if let t = store.sensors.cpuTemp { stat("CPU", String(format: "%.0f°C", t)) }
                    if let t = store.sensors.gpuTemp { stat("GPU", String(format: "%.0f°C", t)) }
                    if let g = store.sensors.gpuActive { stat("GPU load", pctStr(g)) }
                    if let w = store.sensors.gpuPowerW { stat("GPU", String(format: "%.1f W", w)) }
                }
                if !store.sensors.fanRPM.isEmpty {
                    Text("Fans: " + store.sensors.fanRPM.map { String(format: "%.0f rpm", $0) }
                        .joined(separator: " · "))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
                if store.sensors.cpuTemp == nil, store.sensors.gpuTemp == nil,
                   store.sensors.fanRPM.isEmpty, !store.sensors.extra.isEmpty {
                    Text("\(store.sensors.extra.count) raw sensors read (key mapping varies by Mac).")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Button("Remove privileged rule") { store.setSensors(on: false) }
                    .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(accent)
            }
        }
        .padding(14).background(card)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
            dimZeros(value).font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
    }

    private func requestSensors(_ on: Bool) {
        guard on else { store.setSensors(on: false); return }
        let alert = NSAlert()
        alert.messageText = "Enable privileged sensors?"
        alert.informativeText = Privileged.disclosure
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install & Enable")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { store.setSensors(on: true) }
    }

    // MARK: Menu-bar customization

    private var menuBarCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Menu bar", systemImage: "menubar.rectangle")
                .font(.system(size: 12, weight: .semibold))
            Text("Order shown = order in the tray (first is leftmost).")
                .font(.system(size: 10)).foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text("Text size").font(.system(size: 11)).foregroundStyle(.secondary)
                Slider(
                    value: Binding(get: { store.menuBar.fontSize },
                                   set: { store.setMenuBarFontSize($0) }),
                    in: 9...16, step: 1
                )
                Text("\(Int(store.menuBar.fontSize))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, alignment: .trailing)
            }

            ForEach(Array(store.menuBar.widgets.enumerated()), id: \.element) { idx, w in
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                    Text(w.label).font(.system(size: 11))
                    Spacer()
                    Button { store.moveWidget(w, up: true) } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.plain).controlSize(.small)
                    .disabled(idx == 0)
                    Button { store.moveWidget(w, up: false) } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.plain).controlSize(.small)
                    .disabled(idx == store.menuBar.widgets.count - 1)
                    Button { store.toggleWidget(w) } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                    .buttonStyle(.plain).controlSize(.small)
                    .foregroundStyle(.red.opacity(0.75))
                }
                .padding(.vertical, 2)
            }

            let available = MenuBarWidget.allCases.filter {
                !store.menuBar.widgets.contains($0)
            }
            if !available.isEmpty {
                Divider().padding(.vertical, 2)
                Text("Add").font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                ForEach(available) { w in
                    HStack {
                        Text(w.label).font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { store.toggleWidget(w) } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain).controlSize(.small)
                        .foregroundStyle(accent)
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(14).background(card)
    }

    // MARK: Chrome

    private var footer: some View {
        VStack(spacing: 4) {
            if let err = store.lastError {
                Text(err).font(.system(size: 10)).foregroundStyle(.red)
                    .lineLimit(2).onTapGesture { store.lastError = nil }
            }
            HStack {
                Text("up \(uptimeStr)").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .controlSize(.small)
                .help("Quit Stats")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private var uptimeStr: String {
        let s = Int(store.info.uptime)
        let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}
