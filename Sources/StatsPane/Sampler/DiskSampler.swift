import Foundation
import Darwin
import IOKit

struct VolumeInfo: Identifiable {
    let id: String        // mount path
    let name: String
    let total: UInt64
    let free: UInt64
    var used: UInt64 { total > free ? total - free : 0 }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct DiskSample {
    var volumes: [VolumeInfo] = []
    var primary: VolumeInfo?
    var readBytesPerSec: Double = 0
    var writeBytesPerSec: Double = 0
}

/// Volume capacity via `getmntinfo`; throughput via the IOKit
/// IOBlockStorageDriver "Statistics" counters (delta over the interval).
final class DiskSampler {
    private var prevRead: UInt64 = 0
    private var prevWrite: UInt64 = 0
    private var prevStamp = Date()
    private var primed = false

    func sample() -> DiskSample {
        var out = DiskSample()

        var mnt: UnsafeMutablePointer<statfs>?
        let n = getmntinfo(&mnt, MNT_NOWAIT)
        if n > 0, let mnt {
            for i in 0..<Int(n) {
                var fs = mnt[i]
                if (fs.f_flags & UInt32(MNT_RDONLY)) != 0 { continue }
                let typ = withUnsafePointer(to: &fs.f_fstypename) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
                }
                if typ == "devfs" || typ == "autofs" { continue }
                let path = withUnsafePointer(to: &fs.f_mntonname) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) }
                }
                let bs = UInt64(fs.f_bsize)
                let total = UInt64(fs.f_blocks) &* bs
                let free = UInt64(fs.f_bavail) &* bs
                if total == 0 { continue }
                let name = path == "/" ? "Macintosh HD"
                    : (URL(fileURLWithPath: path).lastPathComponent.isEmpty ? path
                       : URL(fileURLWithPath: path).lastPathComponent)
                out.volumes.append(VolumeInfo(id: path, name: name, total: total, free: free))
            }
        }
        out.volumes.sort { $0.total > $1.total }
        out.primary = out.volumes.first { $0.id == "/System/Volumes/Data" } ?? out.volumes.first

        var totalR: UInt64 = 0, totalW: UInt64 = 0
        var it: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault,
                                        IOServiceMatching("IOBlockStorageDriver"),
                                        &it) == KERN_SUCCESS {
            var svc = IOIteratorNext(it)
            while svc != 0 {
                if let prop = IORegistryEntryCreateCFProperty(
                        svc, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                        .takeRetainedValue() as? [String: Any] {
                    totalR &+= (prop["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                    totalW &+= (prop["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
                }
                IOObjectRelease(svc)
                svc = IOIteratorNext(it)
            }
            IOObjectRelease(it)
        }
        let now = Date()
        let dt = max(now.timeIntervalSince(prevStamp), 0.001)
        prevStamp = now
        if primed {
            out.readBytesPerSec = max(0, Double(totalR &- prevRead) / dt)
            out.writeBytesPerSec = max(0, Double(totalW &- prevWrite) / dt)
        }
        prevRead = totalR
        prevWrite = totalW
        primed = true
        return out
    }
}
