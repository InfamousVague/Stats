import Foundation
import Darwin

enum MemoryPressure: String { case normal = "Normal", warning = "Warning", critical = "Critical" }

struct MemorySample {
    var total: UInt64
    var free: UInt64
    var wired: UInt64
    var compressed: UInt64
    var anonymous: UInt64      // app memory (internal, non-purgeable)
    var fileBacked: UInt64     // cached files
    var speculative: UInt64
    var purgeable: UInt64
    var swapTotal: UInt64
    var swapUsed: UInt64
    var pressure: MemoryPressure

    /// "Used" the way Activity Monitor counts it (everything not free/reclaimable).
    var used: UInt64 { wired &+ compressed &+ anonymous }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

final class MemorySampler {
    private let page = UInt64(SystemInfo.shared.pageSize)

    func sample() -> MemorySample {
        var vm = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let total = SystemInfo.shared.physicalMemory
        guard kr == KERN_SUCCESS else {
            return MemorySample(total: total, free: 0, wired: 0, compressed: 0,
                                anonymous: 0, fileBacked: 0, speculative: 0,
                                purgeable: 0, swapTotal: 0, swapUsed: 0, pressure: .normal)
        }
        func b(_ pages: UInt32) -> UInt64 { UInt64(pages) &* page }
        func b64(_ pages: natural_t) -> UInt64 { UInt64(pages) &* page }

        let purgeable = b64(vm.purgeable_count)
        let anon = b64(vm.internal_page_count)
        let appMem = anon > purgeable ? anon - purgeable : anon

        var swap = xsw_usage()
        var ssize = MemoryLayout<xsw_usage>.stride
        sysctlbyname("vm.swapusage", &swap, &ssize, nil, 0)

        return MemorySample(
            total: total,
            free: b64(vm.free_count),
            wired: b64(vm.wire_count),
            compressed: b64(vm.compressor_page_count),
            anonymous: appMem,
            fileBacked: b64(vm.external_page_count),
            speculative: b64(vm.speculative_count),
            purgeable: purgeable,
            swapTotal: swap.xsu_total,
            swapUsed: swap.xsu_used,
            pressure: Self.pressure()
        )
    }

    private static func pressure() -> MemoryPressure {
        switch SystemInfo.sysctlInt("kern.memorystatus_vm_pressure_level") {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }
}
