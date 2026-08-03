import Foundation
import Network

/// eISCP (Integra Serial Control Protocol over Ethernet) — TCP port 60128.
/// Message payload: "!1" + command (e.g. "MVL32"), CR-terminated, wrapped in
/// an "ISCP" header. The receiver pushes state changes to connected clients.
enum EISCP {
    static let port: UInt16 = 60128

    static func packet(_ command: String, unit: Character = "1") -> Data {
        let payload = Data("!\(unit)\(command)\r".utf8)
        var d = Data("ISCP".utf8)
        d.appendBE(16)
        d.appendBE(UInt32(payload.count))
        d.append(contentsOf: [0x01, 0, 0, 0])
        d.append(payload)
        return d
    }

    /// Extracts complete messages from `buffer`, consuming parsed bytes.
    /// Returns payloads with the "!1" prefix and trailing control bytes stripped.
    static func drain(_ buffer: inout [UInt8]) -> [String] {
        var messages: [String] = []
        while true {
            guard buffer.count >= 16 else { break }
            guard buffer[0] == 0x49, buffer[1] == 0x53, buffer[2] == 0x43, buffer[3] == 0x50 else {
                buffer.removeFirst()
                continue
            }
            let headerSize = Int(be32(buffer, 4))
            let dataSize = Int(be32(buffer, 8))
            let total = headerSize + dataSize
            guard headerSize >= 16, dataSize > 0, total <= 65536 else {
                buffer.removeFirst()
                continue
            }
            guard buffer.count >= total else { break }
            var payload = Array(buffer[headerSize..<total])
            buffer.removeFirst(total)
            while let last = payload.last, last < 0x20 || last == 0x1A {
                payload.removeLast()
            }
            var text = String(decoding: payload, as: UTF8.self)
            if text.hasPrefix("!") { text = String(text.dropFirst(2)) }
            if !text.isEmpty { messages.append(text) }
        }
        return messages
    }

    private static func be32(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) << 24 | UInt32(b[o + 1]) << 16 | UInt32(b[o + 2]) << 8 | UInt32(b[o + 3])
    }
}

extension Data {
    mutating func appendBE(_ v: UInt32) {
        var be = v.bigEndian
        Swift.withUnsafeBytes(of: &be) { append(contentsOf: $0) }
    }
}

/// Persistent TCP connection to the receiver with push-message delivery.
@MainActor
final class EISCPConnection {
    private var conn: NWConnection?
    private var buffer: [UInt8] = []
    private(set) var isConnected = false

    var onMessage: ((String) -> Void)?
    var onState: ((Bool) -> Void)?

    func connect(host: String) {
        disconnect()
        let c = NWConnection(host: NWEndpoint.Host(host),
                             port: NWEndpoint.Port(rawValue: EISCP.port)!,
                             using: .tcp)
        conn = c
        c.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self, self.conn === c else { return }
                switch state {
                case .ready:
                    self.isConnected = true
                    self.onState?(true)
                case .failed, .cancelled:
                    self.isConnected = false
                    self.onState?(false)
                default:
                    break
                }
            }
        }
        receive(on: c)
        c.start(queue: .global(qos: .userInitiated))
    }

    func disconnect() {
        conn?.cancel()
        conn = nil
        buffer.removeAll()
        isConnected = false
    }

    func send(_ command: String) {
        conn?.send(content: EISCP.packet(command), completion: .contentProcessed { _ in })
    }

    private func receive(on c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isDone, error in
            Task { @MainActor in
                guard let self, self.conn === c else { return }
                if let data, !data.isEmpty {
                    self.buffer.append(contentsOf: data)
                    for message in EISCP.drain(&self.buffer) {
                        self.onMessage?(message)
                    }
                }
                if isDone || error != nil {
                    self.isConnected = false
                    self.onState?(false)
                    return
                }
                self.receive(on: c)
            }
        }
    }
}
