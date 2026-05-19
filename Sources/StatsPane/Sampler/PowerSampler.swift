import Foundation
import IOKit
import IOKit.ps

struct PowerSample {
    var hasBattery = false
    var percent = 0
    var charging = false
    var onAC = true
    var minutesRemaining = -1   // -1 = calculating/unknown
    var cycleCount = 0
    var healthPercent = 0
    var thermal = "Nominal"
}

/// Battery via IOKit.ps (no privileges); cycle/health via the
/// AppleSmartBattery IORegistry entry; thermal via ProcessInfo.
final class PowerSampler {
    func sample() -> PowerSample {
        var s = PowerSample()

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for src in list {
                guard let d = IOPSGetPowerSourceDescription(blob, src)?
                    .takeUnretainedValue() as? [String: Any] else { continue }
                s.hasBattery = true
                let cur = (d[kIOPSCurrentCapacityKey] as? NSNumber)?.intValue ?? 0
                let mx = (d[kIOPSMaxCapacityKey] as? NSNumber)?.intValue ?? 100
                s.percent = mx > 0 ? Int(Double(cur) / Double(mx) * 100) : 0
                s.charging = (d[kIOPSIsChargingKey] as? Bool) ?? false
                s.onAC = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
                if s.charging {
                    s.minutesRemaining = (d[kIOPSTimeToFullChargeKey] as? NSNumber)?.intValue ?? -1
                } else {
                    s.minutesRemaining = (d[kIOPSTimeToEmptyKey] as? NSNumber)?.intValue ?? -1
                }
            }
        }

        let svc = IOServiceGetMatchingService(kIOMainPortDefault,
                                              IOServiceMatching("AppleSmartBattery"))
        if svc != 0 {
            func num(_ key: String) -> Int {
                (IORegistryEntryCreateCFProperty(svc, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue() as? NSNumber)?.intValue ?? 0
            }
            s.cycleCount = num("CycleCount")
            let design = num("DesignCapacity")
            let rawMax = num("AppleRawMaxCapacity")
            if design > 0, rawMax > 0 { s.healthPercent = Int(Double(rawMax) / Double(design) * 100) }
            IOObjectRelease(svc)
        }

        switch ProcessInfo.processInfo.thermalState {
        case .nominal: s.thermal = "Nominal"
        case .fair: s.thermal = "Fair"
        case .serious: s.thermal = "Serious"
        case .critical: s.thermal = "Critical"
        @unknown default: s.thermal = "—"
        }
        return s
    }
}

/// Fixed-width bytes/sec (zero-padded, e.g. "0001.2 MB/s") so the
/// reading never shifts as it changes. Pair with a monospaced font.
func fmtRate(_ bps: Double) -> String {
    let units = ["B/s ", "KB/s", "MB/s", "GB/s"]
    var v = bps, i = 0
    while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
    return String(format: "%06.1f %@", v, units[i])
}

/// Fixed-width rate as a bare number (no unit) — auto-scaled, zero-padded.
func rateNum(_ bps: Double) -> String {
    var v = bps, i = 0
    while v >= 1024, i < 3 { v /= 1024; i += 1 }
    return String(format: "%06.1f", v)
}
