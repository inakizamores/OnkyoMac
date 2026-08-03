import Foundation

/// Standard eISCP SLI input source codes (hex string → label).
struct OnkyoInput: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let common: [OnkyoInput] = [
        OnkyoInput(code: "12", name: "TV"),
        OnkyoInput(code: "10", name: "BD/DVD"),
        OnkyoInput(code: "01", name: "CBL/SAT"),
        OnkyoInput(code: "02", name: "Game"),
        OnkyoInput(code: "05", name: "PC"),
        OnkyoInput(code: "23", name: "CD"),
        OnkyoInput(code: "2E", name: "Bluetooth"),
        OnkyoInput(code: "2B", name: "Network"),
        OnkyoInput(code: "29", name: "USB"),
        OnkyoInput(code: "03", name: "AUX"),
        OnkyoInput(code: "24", name: "FM"),
        OnkyoInput(code: "25", name: "AM"),
    ]

    static func name(for code: String) -> String {
        common.first(where: { $0.code == code })?.name ?? "Input \(code)"
    }
}
