import Foundation

/// eISCP SLI input sources. The receiver's own selector list (NRI query)
/// replaces this at runtime — these are only the fallback for models
/// that don't answer NRI.
struct OnkyoInput: Identifiable, Hashable, Codable {
    let code: String
    let name: String
    var id: String { code }

    static let common: [OnkyoInput] = [
        OnkyoInput(code: "12", name: "TV"),
        OnkyoInput(code: "11", name: "Strm Box"),
        OnkyoInput(code: "10", name: "BD/DVD"),
        OnkyoInput(code: "01", name: "CBL/SAT"),
        OnkyoInput(code: "02", name: "Game"),
        OnkyoInput(code: "05", name: "PC"),
        OnkyoInput(code: "03", name: "AUX"),
        OnkyoInput(code: "23", name: "CD"),
        OnkyoInput(code: "22", name: "Phono"),
        OnkyoInput(code: "2E", name: "Bluetooth"),
        OnkyoInput(code: "2B", name: "Network"),
        OnkyoInput(code: "29", name: "USB"),
        OnkyoInput(code: "24", name: "FM"),
        OnkyoInput(code: "25", name: "AM"),
    ]
}

/// Parses the <selectorlist> out of the receiver's NRI information XML.
final class SelectorParser: NSObject, XMLParserDelegate {
    private var inputs: [OnkyoInput] = []

    static func parse(_ xml: String) -> [OnkyoInput] {
        let p = SelectorParser()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = p
        parser.parse()
        return p.inputs
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attr: [String: String] = [:]) {
        guard elementName == "selector",
              attr["value"] == "1",
              let id = attr["id"]?.uppercased(),
              id != "80",                       // zone "Source" pseudo-input
              let name = attr["name"]?.trimmingCharacters(in: .whitespaces),
              !name.isEmpty
        else { return }
        inputs.append(OnkyoInput(code: id, name: name))
    }
}

/// HDMI output routing (HDO).
struct OnkyoOutput: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let all: [OnkyoOutput] = [
        OnkyoOutput(code: "01", name: "Main"),
        OnkyoOutput(code: "02", name: "Sub"),
        OnkyoOutput(code: "03", name: "Main + Sub"),
    ]
}

/// Listening modes (LMD) — curated standard codes.
struct OnkyoMode: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let common: [OnkyoMode] = [
        OnkyoMode(code: "00", name: "Stereo"),
        OnkyoMode(code: "01", name: "Direct"),
        OnkyoMode(code: "0C", name: "All Ch Stereo"),
        OnkyoMode(code: "0D", name: "Theater-Dimensional"),
        OnkyoMode(code: "13", name: "Full Mono"),
        OnkyoMode(code: "80", name: "Dolby Surround"),
        OnkyoMode(code: "82", name: "DTS Neural:X"),
    ]

    static func name(for code: String) -> String {
        common.first(where: { $0.code == code })?.name ?? "Mode \(code)"
    }
}
