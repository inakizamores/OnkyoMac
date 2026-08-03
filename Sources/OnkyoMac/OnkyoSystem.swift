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
    var audioInfo = ""
    var model = ""
    var isScanning = false
    var launchAtLogin = LoginItem.isEnabled
    var everConnected = UserDefaults.standard.string(forKey: "receiverIP") != nil
    var connectionFailed = false
    var inputs: [OnkyoInput] = OnkyoInput.common

    /// Transport/now-playing only applies to the receiver's own streaming
    /// sources — not passthrough inputs like STRM BOX or TV.
    var hasTransport: Bool {
        ["2B", "2E", "29", "27", "28", "2A"].contains(inputCode)
    }

    func inputName(_ code: String) -> String {
        inputs.first(where: { $0.code == code })?.name ?? "Input \(code)"
    }

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
                self.connectionFailed = false
                self.everConnected = true
                self.queryAll()
            } else if self.menuIsOpen, !self.reconnectAttempted {
                self.reconnectAttempted = true
                Task { await self.discoverAndConnect() }
            }
        }
        if let saved = UserDefaults.standard.string(forKey: "receiverModel") {
            model = saved
        }
        if let data = UserDefaults.standard.data(forKey: "inputList"),
           let saved = try? JSONDecoder().decode([OnkyoInput].self, from: data),
           !saved.isEmpty {
            inputs = saved
        }
        restoreState()
    }

    /// Last-known receiver state, so the panel renders populated instantly
    /// instead of flashing an empty layout while the connection comes up.
    private func restoreState() {
        guard let s = UserDefaults.standard.dictionary(forKey: "lastState") else { return }
        powerOn = s["powerOn"] as? Bool ?? false
        volume = s["volume"] as? Int ?? 0
        muted = s["muted"] as? Bool ?? false
        inputCode = s["input"] as? String ?? ""
        hdmiOut = s["hdmiOut"] as? String ?? ""
        listeningMode = s["mode"] as? String ?? ""
        audioInfo = s["audioInfo"] as? String ?? ""
    }

    private func persistState() {
        UserDefaults.standard.set([
            "powerOn": powerOn, "volume": volume, "muted": muted,
            "input": inputCode, "hdmiOut": hdmiOut, "mode": listeningMode,
            "audioInfo": audioInfo,
        ] as [String: Any], forKey: "lastState")
    }

    // MARK: - Lifecycle

    func menuOpened() {
        menuIsOpen = true
        reconnectAttempted = false
        if conn.isConnected {
            queryAll()
        } else if let ip = knownIP {
            conn.connect(host: ip)
        } else {
            Task { await discoverAndConnect() }
        }
    }

    func menuClosed() {
        menuIsOpen = false
        persistState()
        conn.disconnect()
        connected = false
    }

    func rescan() {
        UserDefaults.standard.removeObject(forKey: "inputList")
        if conn.isConnected { conn.send("NRIQSTN") }
        Task { await discoverAndConnect() }
    }

    private func discoverAndConnect() async {
        guard !isScanning else { return }
        isScanning = true
        connectionFailed = false
        defer { isScanning = false }
        let found = await OnkyoDiscovery.discover()
        guard let first = found.first else {
            if menuIsOpen { connectionFailed = true }
            return
        }
        knownIP = first.ip
        if !first.model.isEmpty {
            model = first.model
            UserDefaults.standard.set(first.model, forKey: "receiverModel")
        }
        if menuIsOpen { conn.connect(host: first.ip) }
    }

    private func queryAll() {
        for q in ["PWRQSTN", "MVLQSTN", "AMTQSTN", "SLIQSTN", "ECNQSTN",
                  "HDOQSTN", "LMDQSTN", "NSTQSTN", "NTIQSTN", "NATQSTN", "IFAQSTN"] {
            conn.send(q)
        }
        // Ask the receiver for its own input list (with custom names) once;
        // Rescan clears the cache to pick up renames.
        if UserDefaults.standard.data(forKey: "inputList") == nil {
            conn.send("NRIQSTN")
        }
    }

    /// A receiver restores its own startup volume/input/mode while booting
    /// and answers "N/A" until ready — re-query the full state a few times
    /// across the boot window so the panel converges on the real values.
    private func requeryAfterPowerOn() {
        Task {
            for delay: UInt64 in [1, 3, 6] {
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
                guard conn.isConnected else { return }
                queryAll()
            }
        }
    }

    /// The format info lags input/mode switches — re-ask once things settle.
    private func requeryAudioInfo() {
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            conn.send("IFAQSTN")
        }
    }

    /// IFA: "source,codec,rate,in-ch,mode,out-ch,…" → "codec → mode · out-ch"
    static func formatAudioInfo(_ value: String) -> String {
        let f = value.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        func field(_ i: Int) -> String { i < f.count ? f[i] : "" }
        var result = ""
        let codec = field(1), mode = field(4), out = field(5)
        if !codec.isEmpty { result = codec }
        if !mode.isEmpty { result += result.isEmpty ? mode : " → \(mode)" }
        if !out.isEmpty { result += result.isEmpty ? out : " · \(out)" }
        return result
    }

    // MARK: - Incoming state (receiver pushes changes)

    private func handle(_ message: String) {
        guard message.count >= 3 else { return }
        let cmd = String(message.prefix(3))
        let value = String(message.dropFirst(3))
        switch cmd {
        case "PWR":
            let on = value == "01"
            let turnedOn = on && !powerOn
            powerOn = on
            if turnedOn { requeryAfterPowerOn() }
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
                requeryAudioInfo()
            }
        case "HDO":
            hdmiOut = value
        case "LMD":
            listeningMode = value
            requeryAudioInfo()
        case "IFA":
            audioInfo = Self.formatAudioInfo(value)
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
        case "NRI":
            let parsed = SelectorParser.parse(value)
            if !parsed.isEmpty {
                inputs = parsed
                if let data = try? JSONEncoder().encode(parsed) {
                    UserDefaults.standard.set(data, forKey: "inputList")
                }
            }
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
        reconnectAttempted = false   // wake can reset the TCP session
        conn.send(powerOn ? "PWR01" : "PWR00")
        if powerOn { requeryAfterPowerOn() }
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
