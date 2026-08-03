import Foundation
import Darwin

/// eISCP discovery: UDP broadcast of "!xECNQSTN" on port 60128.
/// Receivers reply with "ECN<model>/<port>/<region>/<mac>".
enum OnkyoDiscovery {
    static func discover(timeout: TimeInterval = 2.0) async -> [(ip: String, model: String)] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: search(timeout: timeout))
            }
        }
    }

    private static func search(timeout: TimeInterval) -> [(ip: String, model: String)] {
        var found: [String: String] = [:]
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return [] }
        defer { close(fd) }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        var tv = timeval(tv_sec: 0, tv_usec: 250_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = EISCP.port.bigEndian
        addr.sin_addr.s_addr = inet_addr("255.255.255.255")

        let probe = [UInt8](EISCP.packet("ECNQSTN", unit: "x"))
        for _ in 0..<3 {
            _ = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, probe, probe.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        let deadline = Date().addingTimeInterval(timeout)
        var buf = [UInt8](repeating: 0, count: 2048)
        while Date() < deadline {
            var from = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    recvfrom(fd, &buf, buf.count, 0, sa, &fromLen)
                }
            }
            guard n > 0 else { continue }
            var chunk = Array(buf[0..<n])
            let messages = EISCP.drain(&chunk)
            guard let ecn = messages.first(where: { $0.hasPrefix("ECN") }) else { continue }
            let model = String(ecn.dropFirst(3)).split(separator: "/").first.map(String.init) ?? ""
            var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            var sin = from.sin_addr
            if inet_ntop(AF_INET, &sin, &ipBuf, socklen_t(INET_ADDRSTRLEN)) != nil {
                found[String(cString: ipBuf)] = model
            }
        }
        return found.map { (ip: $0.key, model: $0.value) }.sorted { $0.ip < $1.ip }
    }
}
