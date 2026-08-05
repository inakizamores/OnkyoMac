import SwiftUI
import AppKit

/// Renders the real UI to PNGs for the README when the app is launched
/// with `--render-screenshots <dir>`. Not reachable in normal use.
@MainActor
enum ScreenshotRenderer {
    static func runIfRequested() {
        guard let i = CommandLine.arguments.firstIndex(of: "--render-screenshots"),
              CommandLine.arguments.count > i + 1 else { return }
        renderAll(to: CommandLine.arguments[i + 1])
        exit(0)
    }

    private static func sampleSystem() -> OnkyoSystem {
        let sys = OnkyoSystem()
        sys.everConnected = true
        sys.connectionFailed = false
        sys.connected = true
        sys.model = "HT-R695"
        sys.powerOn = true
        sys.volume = 38
        sys.muted = false
        sys.inputCode = "2B"
        sys.inputs = [
            OnkyoInput(code: "10", name: "BD/DVD"),
            OnkyoInput(code: "01", name: "CBL/SAT"),
            OnkyoInput(code: "02", name: "GAME"),
            OnkyoInput(code: "11", name: "STRM BOX"),
            OnkyoInput(code: "05", name: "PC"),
            OnkyoInput(code: "12", name: "TV"),
            OnkyoInput(code: "23", name: "CD"),
            OnkyoInput(code: "2B", name: "NET"),
            OnkyoInput(code: "2E", name: "BLUETOOTH"),
        ]
        sys.hdmiOut = "01"
        sys.listeningMode = "0C"
        sys.trackTitle = "Nothing You Can't Do"
        sys.trackArtist = "Max Light Quartet"
        sys.trackTime = "00:01:24/00:03:40"
        sys.isPlaying = true
        sys.audioInfo = "All Ch Stereo · 7.1 ch"
        sys.artwork = placeholderArt()
        return sys
    }

    private static func placeholderArt() -> NSImage {
        let img = NSImage(size: NSSize(width: 84, height: 84))
        img.lockFocus()
        NSGradient(starting: NSColor(calibratedRed: 0.35, green: 0.25, blue: 0.65, alpha: 1),
                   ending: NSColor(calibratedRed: 0.12, green: 0.35, blue: 0.55, alpha: 1))!
            .draw(in: NSRect(x: 0, y: 0, width: 84, height: 84), angle: -60)
        if let sym = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil),
           let cfg = sym.withSymbolConfiguration(.init(pointSize: 34, weight: .medium)) {
            let size = cfg.size
            let tinted = NSImage(size: size)
            tinted.lockFocus()
            cfg.draw(in: NSRect(origin: .zero, size: size))
            NSColor.white.withAlphaComponent(0.85).set()
            NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            tinted.draw(in: NSRect(x: 42 - size.width / 2, y: 42 - size.height / 2,
                                   width: size.width, height: size.height))
        }
        img.unlockFocus()
        return img
    }

    private static func renderAll(to dir: String) {
        let sys = sampleSystem()
        render(MenuView().environment(sys), name: "screenshot-panel", dir: dir)
    }

    private static func render<V: View>(_ view: V, name: String, dir: String) {
        let content = view
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.13))
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .padding(32)
            .environment(\.colorScheme, .dark)
            .environment(\.isScreenshotting, true)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("render failed: \(name)")
            return
        }
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        print("rendered \(name).png")
    }
}
