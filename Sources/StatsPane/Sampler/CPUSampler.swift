import Foundation
import Darwin

struct CPUSample {
    var perCore: [Double]      // 0...1 per logical core
    var total: Double          // 0...1 aggregate
    var loadAverage: (Double, Double, Double)

    /// Average over the performance ("P") cluster — first `perfCores` cores.
    func perfAverage(_ n: Int) -> Double {
        let s = perCore.prefix(n)
        return s.isEmpty ? 0 : s.reduce(0, +) / Double(s.count)
    }
    func effAverage(perf: Int) -> Double {
        let s = perCore.dropFirst(perf)
        return s.isEmpty ? 0 : s.reduce(0, +) / Double(s.count)
    }
}

/// Per-core CPU utilisation from Mach `host_processor_info`, computed as
/// the delta in tick counters between successive samples.
final class CPUSampler {
    private var prevTicks: [[UInt32]] = []   // [core][state]

    func sample() -> CPUSample {
        var cpuLoad: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0

        let kr = host_processor_info(mach_host_self(),
                                     PROCESSOR_CPU_LOAD_INFO,
                                     &cpuCount, &cpuLoad, &infoCount)
        guard kr == KERN_SUCCESS, let cpuLoad else {
            return CPUSample(perCore: [], total: 0, loadAverage: loadAvg())
        }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: cpuLoad),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let states = Int(CPU_STATE_MAX)
        let n = Int(cpuCount)
        var ticks = [[UInt32]](repeating: [UInt32](repeating: 0, count: states), count: n)
        cpuLoad.withMemoryRebound(to: UInt32.self, capacity: n * states) { ptr in
            for c in 0..<n {
                for s in 0..<states { ticks[c][s] = ptr[c * states + s] }
            }
        }

        var perCore = [Double](repeating: 0, count: n)
        if prevTicks.count == n {
            for c in 0..<n {
                let dU = Double(ticks[c][Int(CPU_STATE_USER)] &- prevTicks[c][Int(CPU_STATE_USER)])
                let dS = Double(ticks[c][Int(CPU_STATE_SYSTEM)] &- prevTicks[c][Int(CPU_STATE_SYSTEM)])
                let dN = Double(ticks[c][Int(CPU_STATE_NICE)] &- prevTicks[c][Int(CPU_STATE_NICE)])
                let dI = Double(ticks[c][Int(CPU_STATE_IDLE)] &- prevTicks[c][Int(CPU_STATE_IDLE)])
                let busy = dU + dS + dN
                let total = busy + dI
                perCore[c] = total > 0 ? min(1, busy / total) : 0
            }
        }
        prevTicks = ticks
        let total = perCore.isEmpty ? 0 : perCore.reduce(0, +) / Double(perCore.count)
        return CPUSample(perCore: perCore, total: total, loadAverage: loadAvg())
    }

    private func loadAvg() -> (Double, Double, Double) {
        var l = [Double](repeating: 0, count: 3)
        getloadavg(&l, 3)
        return (l[0], l[1], l[2])
    }
}
