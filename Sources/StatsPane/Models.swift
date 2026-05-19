import Foundation
import Observation
import AppKit

/// Fixed-length rolling buffer for the time-series charts.
struct Ring {
    private(set) var values: [Double]
    let capacity: Int
    init(_ capacity: Int) { self.capacity = capacity; values = [] }
    mutating func push(_ v: Double) {
        values.append(v)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }
}

@MainActor
@Observable
final class StatsStore {
    var cpu = CPUSample(perCore: [], total: 0, loadAverage: (0, 0, 0))
    var memory = MemorySample(total: SystemInfo.shared.physicalMemory, free: 0, wired: 0,
                              compressed: 0, anonymous: 0, fileBacked: 0, speculative: 0,
                              purgeable: 0, swapTotal: 0, swapUsed: 0, pressure: .normal)
    var topByMemory: [ProcInfo] = []
    var topByCPU: [ProcInfo] = []
    var disk = DiskSample()
    var net = NetSample()
    var power = PowerSample()
    var sensors = SensorsSample()
    var sensorsEnabled = Privileged.enabled
    var lastError: String?

    var cpuHistory = Ring(60)
    var memHistory = Ring(60)
    var netHistory = Ring(60)   // normalised rx+tx for the sparkline
    var menuBar = MenuBarSettings.load()

    let info = SystemInfo.shared

    /// Enable/disable a menu-bar widget, persist, and re-render the tray.
    func toggleWidget(_ w: MenuBarWidget) {
        if let idx = menuBar.widgets.firstIndex(of: w) {
            menuBar.widgets.remove(at: idx)
        } else {
            menuBar.widgets.append(w)
        }
        if menuBar.widgets.isEmpty { menuBar.widgets = [.icon] }
        menuBar.save()
        onTick?()
    }

    /// Reorder a widget in the tray (left = earlier in the array).
    func moveWidget(_ w: MenuBarWidget, up: Bool) {
        guard let i = menuBar.widgets.firstIndex(of: w) else { return }
        let j = up ? i - 1 : i + 1
        guard menuBar.widgets.indices.contains(j) else { return }
        menuBar.widgets.swapAt(i, j)
        menuBar.save()
        onTick?()
    }

    /// Apply a new full order (used by drag-to-reorder).
    func reorderWidgets(_ widgets: [MenuBarWidget]) {
        menuBar.widgets = widgets.isEmpty ? [.icon] : widgets
        menuBar.save()
        onTick?()
    }

    @ObservationIgnored private let cpuSampler = CPUSampler()
    @ObservationIgnored private let memSampler = MemorySampler()
    @ObservationIgnored private let procSampler = ProcessSampler()
    @ObservationIgnored private let diskSampler = DiskSampler()
    @ObservationIgnored private let netSampler = NetSampler()
    @ObservationIgnored private let powerSampler = PowerSampler()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var tickN = 0
    @ObservationIgnored var onTick: (() -> Void)?

    // MARK: Suite integration (deep links)

    static let alfredBundle = "com.mattssoftware.alfred"
    static let portBundle = "com.mattssoftware.port"
    static let blipBundle = "com.infamousvague.blip"

    func installed(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
    var alfredInstalled: Bool { installed(Self.alfredBundle) }
    var portInstalled: Bool { installed(Self.portBundle) }
    var blipInstalled: Bool { installed(Self.blipBundle) }

    func openScheme(_ scheme: String) {
        if let url = URL(string: "\(scheme)://open") { NSWorkspace.shared.open(url) }
    }

    /// Enable/disable privileged sensors (disclosure shown by the UI first).
    func setSensors(on: Bool) {
        let err = on ? Privileged.install() : Privileged.remove()
        if let err { lastError = err }
        sensorsEnabled = Privileged.enabled
        if !sensorsEnabled { sensors = SensorsSample() }
    }

    func start(interval: TimeInterval = 1.5) {
        guard timer == nil else { return }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        let c = cpuSampler.sample()
        let m = memSampler.sample()
        let (mem, cpuTop) = procSampler.sample()
        cpu = c
        memory = m
        topByMemory = mem
        topByCPU = cpuTop
        disk = diskSampler.sample()
        net = netSampler.sample()
        power = powerSampler.sample()
        cpuHistory.push(c.total)
        memHistory.push(m.usedFraction)
        // Normalise net to a rolling 0...1 (relative to a 5 MB/s soft ceiling).
        netHistory.push(min(1, (net.rxBytesPerSec + net.txBytesPerSec) / 5_000_000))
        tickN &+= 1
        // Sensors are heavy (sudo + powermetrics) and slow-changing: sample
        // every ~4th tick, off the main actor.
        if sensorsEnabled, tickN % 4 == 0 {
            Task.detached {
                let s = SensorsSampler.sample()
                await MainActor.run { self.sensors = s }
            }
        }
        onTick?()
    }
}
