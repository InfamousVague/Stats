import Foundation
import Darwin

struct NetSample {
    var rxBytesPerSec: Double = 0
    var txBytesPerSec: Double = 0
    var primaryInterface: String = "—"
}

/// Aggregate network throughput from the AF_LINK `if_data` byte counters
/// (delta over the interval). Loopback excluded.
final class NetSampler {
    private var prevRx: UInt64 = 0
    private var prevTx: UInt64 = 0
    private var prevStamp = Date()
    private var primed = false

    func sample() -> NetSample {
        var rx: UInt64 = 0, tx: UInt64 = 0
        var primary = ""

        var ifap: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifap) == 0, let first = ifap {
            for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
                guard let addr = ptr.pointee.ifa_addr,
                      addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
                let name = String(cString: ptr.pointee.ifa_name)
                if name == "lo0" { continue }
                guard let raw = ptr.pointee.ifa_data else { continue }
                let d = raw.assumingMemoryBound(to: if_data.self).pointee
                rx &+= UInt64(d.ifi_ibytes)
                tx &+= UInt64(d.ifi_obytes)
                if primary.isEmpty, name.hasPrefix("en"), d.ifi_ibytes > 0 { primary = name }
            }
            freeifaddrs(ifap)
        }

        let now = Date()
        let dt = max(now.timeIntervalSince(prevStamp), 0.001)
        prevStamp = now
        var s = NetSample(primaryInterface: primary.isEmpty ? "—" : primary)
        if primed {
            s.rxBytesPerSec = max(0, Double(rx &- prevRx) / dt)
            s.txBytesPerSec = max(0, Double(tx &- prevTx) / dt)
        }
        prevRx = rx
        prevTx = tx
        primed = true
        return s
    }
}
