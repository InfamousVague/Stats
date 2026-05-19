import Foundation

struct SensorsSample {
    var cpuTemp: Double?     // °C
    var gpuTemp: Double?     // °C
    var fanRPM: [Double] = []
    var gpuActive: Double?   // 0...1
    var gpuPowerW: Double?   // watts
    var extra: [(String, Double)] = []   // other discovered numeric sensors
    var available = false
}

/// Runs the privileged `powermetrics` sample and best-effort parses the
/// plist. Key names vary by macOS/silicon, so it scans defensively and
/// degrades gracefully rather than assuming a fixed schema.
enum SensorsSampler {
    static func sample() -> SensorsSample {
        var s = SensorsSample()
        guard Privileged.enabled else { return s }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        // `-n`: never prompt — if the NOPASSWD rule is wrong, fail fast
        // instead of hanging on a non-existent TTY.
        p.arguments = ["-n"] + Privileged.pmArgs
        let out = Pipe(); p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return s }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let plist = Self.parsePlist(data)
        else { return s }

        s.available = true
        scan(plist, into: &s)
        // Heuristic typed fills from whatever was discovered.
        for (k, v) in s.extra {
            let lk = k.lowercased()
            if s.cpuTemp == nil, lk.contains("cpu"), lk.contains("temp") { s.cpuTemp = v }
            if s.gpuTemp == nil, lk.contains("gpu"), lk.contains("temp") { s.gpuTemp = v }
            if lk.contains("fan"), v > 0, v < 30_000 { s.fanRPM.append(v) }
            if s.gpuPowerW == nil, lk.contains("gpu"), lk.contains("power") { s.gpuPowerW = v / 1000 }
            if s.gpuActive == nil, lk.contains("gpu"), lk.contains("active") {
                s.gpuActive = v > 1 ? v / 100 : v
            }
        }
        return s
    }

    /// `powermetrics --format plist` can emit a preamble line and/or a
    /// trailing NUL, and streams one plist per sample. Strip to the first
    /// real plist document and parse defensively.
    private static func parsePlist(_ raw: Data) -> [String: Any]? {
        var data = raw
        if let r = raw.range(of: Data("<?xml".utf8)) {
            data = raw.subdata(in: r.lowerBound..<raw.endIndex)
        } else if let r = raw.range(of: Data("bplist00".utf8)) {
            data = raw.subdata(in: r.lowerBound..<raw.endIndex)
        }
        while let last = data.last, last == 0 || last == 0x0a || last == 0x20 {
            data.removeLast()
        }
        if let pl = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [String: Any] { return pl }
        if let end = data.range(of: Data("</plist>".utf8)) {
            let first = data.subdata(in: data.startIndex..<end.upperBound)
            return try? PropertyListSerialization.propertyList(
                from: first, options: [], format: nil) as? [String: Any]
        }
        return nil
    }

    /// Recursively collect every numeric leaf with its key path.
    private static func scan(_ node: Any, prefix: String = "", into s: inout SensorsSample) {
        if let dict = node as? [String: Any] {
            for (k, v) in dict { scan(v, prefix: prefix.isEmpty ? k : "\(prefix).\(k)", into: &s) }
        } else if let arr = node as? [Any] {
            for (i, v) in arr.enumerated() { scan(v, prefix: "\(prefix)[\(i)]", into: &s) }
        } else if let num = node as? NSNumber,
                  CFGetTypeID(num) != CFBooleanGetTypeID() {
            let d = num.doubleValue
            if d.isFinite, d != 0 { s.extra.append((prefix, d)) }
        }
    }
}
