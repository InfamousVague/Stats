import Foundation
import Darwin

struct ProcInfo: Identifiable {
    let id: Int32          // pid
    let name: String
    let memory: UInt64     // physical footprint, bytes
    let cpu: Double        // 0...1 of one core-second over the interval
}

/// Top processes by memory (phys_footprint) and CPU, via libproc.
/// All no-privilege; CPU is the delta of cumulative user+system time.
final class ProcessSampler {
    private var prevCPU: [Int32: UInt64] = [:]   // pid -> ns
    private var prevStamp = Date()

    func sample(limit: Int = 8) -> (byMemory: [ProcInfo], byCPU: [ProcInfo]) {
        let now = Date()
        let elapsedNs = max(now.timeIntervalSince(prevStamp), 0.001) * 1_000_000_000
        prevStamp = now

        var count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard count > 0 else { return ([], []) }
        var pids = [Int32](repeating: 0, count: Int(count) / MemoryLayout<Int32>.stride)
        count = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, count)
        let n = Int(count) / MemoryLayout<Int32>.stride

        var out: [ProcInfo] = []
        var nextCPU: [Int32: UInt64] = [:]
        for i in 0..<n {
            let pid = pids[i]
            guard pid > 0 else { continue }
            var ru = rusage_info_v4()
            let rc = withUnsafeMutablePointer(to: &ru) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard rc == 0 else { continue }
            let cpuNs = ru.ri_user_time &+ ru.ri_system_time
            nextCPU[pid] = cpuNs
            let deltaNs = prevCPU[pid].map { cpuNs >= $0 ? cpuNs - $0 : 0 } ?? 0
            let cpu = min(Double(SystemInfo.shared.coreCount), Double(deltaNs) / elapsedNs)

            var nameBuf = [CChar](repeating: 0, count: 256)
            proc_name(pid, &nameBuf, 256)
            let name = String(cString: nameBuf)

            out.append(ProcInfo(id: pid,
                                name: name.isEmpty ? "pid \(pid)" : name,
                                memory: ru.ri_phys_footprint,
                                cpu: cpu))
        }
        prevCPU = nextCPU
        let byMem = out.sorted { $0.memory > $1.memory }.prefix(limit)
        let byCPU = out.sorted { $0.cpu > $1.cpu }.prefix(limit)
        return (Array(byMem), Array(byCPU))
    }
}
