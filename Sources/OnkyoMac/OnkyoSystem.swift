import Foundation
import Observation
import ServiceManagement
import AppKit

@MainActor
final class Throttler {
    private let interval: TimeInterval
    private var lastFire: Date = .distantPast
    private var pending: Task<Void, Never>?

    init(interval: TimeInterval = 0.1) { self.interval = interval }

    func call(_ op: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = nil
        let elapsed = Date().timeIntervalSince(lastFire)
        if elapsed >= interval {
            lastFire = Date()
            op()
        } else {
            pending = Task {
                try? await Task.sleep(nanoseconds: UInt64((self.interval - elapsed) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.lastFire = Date()
                op()
            }
        }
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("OnkyoMac: launch at login failed: \(error.localizedDescription)")
        }
    }
}

@MainActor
@Observable
final class OnkyoSystem {
    var connected = false
    var powerOn = false
    var volume = 0            // raw MVL value 0...100
    var muted = false
    var inputCode = ""
    var hdmiOut = ""
    var listeningMode = ""
    var trackTitle = ""
    var trackArtist = ""
    var trackTime = ""
    var isPlaying = false
    var artwork: NSImage?
    var model = ""
    var isScanning = false
    var launchAtLogin = LoginItem.isEnabled

    @ObservationIgnored private var artHex = ""

    @ObservationIgnored private let conn = EISCPConnection()
    @ObservationIgnored private var menuIsOpen = false
    @ObservationIgnored private var suppressVolumeUntil: Date = .distantPast
    @ObservationIgnored private let volumeThrottler = Throttler()
    @ObservationIgnored private var reconnectAttempted = false

    private var knownIP: String? {
        get { UserDefaults.standard.string(forKey: "receiverIP") }
        set { UserDefaults.standard.set(newValue, forKey: "receiverIP") }
    }

    init() {
        conn.onMessage = { [weak self] in self?.handle($0) }
        conn.onState = { [weak self] up in
            guard let self else { return }
            self.connected = up
            if up {
                self.reconnectAttempted = false
                self.queryAll()
            } else if self.menuIsOpen, !self.reconnectAttempted {
                self.reconnectAttempted = true
                Task { await self.discoverAndConnect() }
            }
        }
        if let saved = UserDefaults.standard.string(forKey: "receiverModel") {
            model = saved
        }
    }

    // MARK: - Lifecycle

    func menuOpened() {
        menuIsOpen = true
        reconnectAttempted = false
        if let ip = knownIP {
            conn.connect(host: ip)
        } else {
            Task { await discoverAndConnect() }
        }
    }

    func menuClosed() {
        menuIsOpen = false
        conn.disconnect()
        connected = false
    }

    func rescan() {
        Task { await discoverAndConnect() }
    }

    private func discoverAndConnect() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        let found = await OnkyoDiscovery.discover()
        guard let first = found.first else { return }
        knownIP = first.ip
        if !first.model.isEmpty {
            model = first.model
            UserDefaults.standard.set(first.model, forKey: "receiverModel")
        }
        if menuIsOpen { conn.connect(host: first.ip) }
    }

    private func queryAll() {
        for q in ["PWRQSTN", "MVLQSTN", "AMTQSTN", "SLIQSTN", "ECNQSTN",
                  "HDOQSTN", "LMDQSTN", "NSTQSTN", "NTIQSTN", "NATQSTN"] {
            conn.send(q)
        }
    }

    // MARK: - Incoming state (receiver pushes changes)

    private func handle(_ message: String) {
        guard message.count >= 3 else { return }
        let cmd = String(message.prefix(3))
        let value = String(message.dropFirst(3))
        switch cmd {
        case "PWR":
            powerOn = value == "01"
        case "MVL":
            if Date() >= suppressVolumeUntil, let v = Int(value, radix: 16) {
                volume = min(100, v)
            }
        case "AMT":
            muted = value == "01"
        case "SLI":
            if value != inputCode {
                inputCode = value
                trackTitle = ""; trackArtist = ""; trackTime = ""
                artwork = nil; artHex = ""
            }
        case "HDO":
            hdmiOut = value
        case "LMD":
            listeningMode = value
        case "NTI":
            trackTitle = value
        case "NAT":
            trackArtist = value
        case "NTM":
            trackTime = value
        case "NST":
            if let s = value.first { isPlaying = "PFR".contains(s) }
        case "NJA":
            handleArt(value)
        case "ECN":
            if let m = value.split(separator: "/").first, !m.isEmpty {
                model = String(m)
                UserDefaults.standard.set(model, forKey: "receiverModel")
            }
        default:
            break
        }
    }

    /// NJA album art: "<type><packet><hex…>" — type 1 = JPEG, 0 = BMP, n = none;
    /// packet 0 = start, 1 = middle, 2 = end, "-" = complete in one message.
    private func handleArt(_ value: String) {
        guard let type = value.first else { return }
        if type == "n" { artwork = nil; artHex = ""; return }
        guard value.count >= 2 else { return }
        let flag = value[value.index(value.startIndex, offsetBy: 1)]
        let hex = String(value.dropFirst(2))
        switch flag {
        case "0": artHex = hex
        case "1": artHex += hex
        case "2", "-":
            if flag == "-" { artHex = hex } else { artHex += hex }
            if let data = Data(hexString: artHex), let img = NSImage(data: data) {
                artwork = img
            }
            artHex = ""
        default:
            break
        }
    }

    // MARK: - Actions

    func setVolume(_ v: Int) {
        let clamped = max(0, min(100, v))
        volume = clamped
        suppressVolumeUntil = Date().addingTimeInterval(1.2)
        volumeThrottler.call { [conn] in
            conn.send(String(format: "MVL%02X", clamped))
        }
    }

    func toggleMute() {
        muted.toggle()
        conn.send(muted ? "AMT01" : "AMT00")
    }

    func togglePower() {
        powerOn.toggle()
        conn.send(powerOn ? "PWR01" : "PWR00")
    }

    func setInput(_ code: String) {
        inputCode = code
        conn.send("SLI\(code)")
    }

    func setOutput(_ code: String) {
        hdmiOut = code
        conn.send("HDO\(code)")
    }

    func setMode(_ code: String) {
        listeningMode = code
        conn.send("LMD\(code)")
    }

    func playPause() {
        conn.send(isPlaying ? "NTCPAUSE" : "NTCPLAY")
        isPlaying.toggle()
    }

    func nextTrack() { conn.send("NTCTRUP") }
    func previousTrack() { conn.send("NTCTRDN") }

    func setLaunchAtLogin(_ on: Bool) {
        LoginItem.set(on)
        launchAtLogin = LoginItem.isEnabled
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}

extension Data {
    init?(hexString: String) {
        let chars = Array(hexString.utf8)
        guard chars.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 2)
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let hi = Self.nibble(chars[i]), let lo = Self.nibble(chars[i + 1]) else { return nil }
            bytes.append(hi << 4 | lo)
        }
        self.init(bytes)
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 0x30...0x39: return c - 0x30
        case 0x41...0x46: return c - 0x41 + 10
        case 0x61...0x66: return c - 0x61 + 10
        default: return nil
        }
    }
}
