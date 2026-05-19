import Foundation
import Darwin
import SwiftUI

/// Render a fixed-width number with its leading-zero padding dimmed, so the
/// column never shifts but the eye still reads the significant digits.
/// Keeps a single integer zero visible (e.g. "0.4" dims only "0").
func dimZeros(_ s: String, dim: Color = Color.gray.opacity(0.4)) -> Text {
    let c = Array(s)
    var i = 0
    while i < c.count, c[i] == "0" { i += 1 }
    if i > 0, i == c.count || c[i] == "." { i -= 1 }
    return Text(String(c[..<i])).foregroundStyle(dim)
        + Text(String(c[i...]))
}

/// Static machine facts read once at launch via sysctl.
struct SystemInfo {
    let model: String          // "Apple M5"
    let coreCount: Int         // logical cores
    let perfCores: Int         // performance ("P") cores
    let effCores: Int          // efficiency ("E") cores
    let perfName: String       // perflevel0 name
    let effName: String        // perflevel1 name
    let pageSize: UInt         // VM page size (16384 on Apple Silicon)
    let physicalMemory: UInt64 // bytes
    let osVersion: String
    let bootDate: Date

    static let shared = SystemInfo()

    private init() {
        model = SystemInfo.sysctlString("machdep.cpu.brand_string") ?? "Mac"
        coreCount = Int(SystemInfo.sysctlInt("hw.logicalcpu") ?? 1)
        perfCores = Int(SystemInfo.sysctlInt("hw.perflevel0.physicalcpu") ?? SystemInfo.sysctlInt("hw.physicalcpu") ?? 1)
        effCores = Int(SystemInfo.sysctlInt("hw.perflevel1.physicalcpu") ?? 0)
        perfName = SystemInfo.sysctlString("hw.perflevel0.name") ?? "Performance"
        effName = SystemInfo.sysctlString("hw.perflevel1.name") ?? "Efficiency"
        var ps: vm_size_t = 0
        host_page_size(mach_host_self(), &ps)
        pageSize = UInt(ps)
        physicalMemory = SystemInfo.sysctlUInt64("hw.memsize") ?? 0
        let v = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        var tv = timeval()
        var size = MemoryLayout<timeval>.stride
        if sysctlbyname("kern.boottime", &tv, &size, nil, 0) == 0 {
            bootDate = Date(timeIntervalSince1970: TimeInterval(tv.tv_sec))
        } else {
            bootDate = Date()
        }
    }

    var uptime: TimeInterval { Date().timeIntervalSince(bootDate) }

    // MARK: - sysctl helpers

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
        return String(cString: buf)
    }

    static func sysctlInt(_ name: String) -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.stride
        if sysctlbyname(name, &value, &size, nil, 0) == 0 { return value }
        var v32: Int32 = 0
        size = MemoryLayout<Int32>.stride
        if sysctlbyname(name, &v32, &size, nil, 0) == 0 { return Int64(v32) }
        return nil
    }

    static func sysctlUInt64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.stride
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }
}

/// Fixed-width byte formatting (zero-padded so values never shift, e.g.
/// "0024.0 GB", "0001.2 MB"). Pair with a monospaced font.
func fmtBytes(_ bytes: UInt64) -> String {
    let units = ["B ", "KB", "MB", "GB", "TB"]
    var v = Double(bytes), i = 0
    while v >= 1024, i < units.count - 1 { v /= 1024; i += 1 }
    return String(format: "%06.1f %@", v, units[i])
}

/// Fixed-width 3-digit percent ("007%", "042%", "100%") — leading zeros
/// keep the column from shifting as the value changes.
func pctStr(_ fraction: Double) -> String {
    let p = max(0, min(100, Int((fraction * 100).rounded())))
    return String(format: "%03d%%", p)
}
func pctStr(_ percent: Int) -> String {
    String(format: "%03d%%", max(0, min(100, percent)))
}
