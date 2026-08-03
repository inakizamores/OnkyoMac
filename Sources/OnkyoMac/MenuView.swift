import SwiftUI

struct MenuView: View {
    @Environment(OnkyoSystem.self) private var onkyo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if onkyo.connected {
                CapsuleSlider(
                    value: Binding(
                        get: { Double(onkyo.volume) },
                        set: { onkyo.setVolume(Int($0.rounded())) }
                    ),
                    icon: onkyo.muted ? "speaker.slash.fill" : "speaker.fill",
                    onIconTap: { onkyo.toggleMute() }
                )
                .disabled(!onkyo.powerOn)
                .opacity(onkyo.powerOn ? 1 : 0.4)
                if onkyo.powerOn && !onkyo.trackTitle.isEmpty {
                    nowPlaying
                }
                Group {
                    inputRow
                    pickerRow("Output", selection: Binding(
                        get: { onkyo.hdmiOut },
                        set: { onkyo.setOutput($0) }
                    ), options: OnkyoOutput.all.map { ($0.code, $0.name) })
                    pickerRow("Sound Mode", selection: Binding(
                        get: { onkyo.listeningMode },
                        set: { onkyo.setMode($0) }
                    ), options: OnkyoMode.common.map { ($0.code, $0.name) })
                }
                .disabled(!onkyo.powerOn)
                .opacity(onkyo.powerOn ? 1 : 0.4)
                if onkyo.powerOn && !onkyo.audioInfo.isEmpty {
                    Text(onkyo.audioInfo)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            } else {
                disconnectedState
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .frame(width: 320)
        .onAppear { onkyo.menuOpened() }
        .onDisappear { onkyo.menuClosed() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Onkyo")
                .font(.system(.body, weight: .bold))
            if !onkyo.model.isEmpty {
                Text(onkyo.model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if onkyo.connected {
                Button { onkyo.togglePower() } label: {
                    Image(systemName: "power")
                        .fontWeight(.semibold)
                        .foregroundStyle(onkyo.powerOn ? AnyShapeStyle(Color.accentColor)
                                                       : AnyShapeStyle(.secondary))
                        .frame(width: 22, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(onkyo.powerOn ? "Turn off" : "Turn on")
            }
            settingsMenu
        }
    }

    private var nowPlaying: some View {
        HStack(spacing: 10) {
            if let art = onkyo.artwork {
                Image(nsImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(onkyo.trackTitle)
                    .lineLimit(1)
                if !onkyo.trackArtist.isEmpty {
                    Text(onkyo.trackArtist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !onkyo.trackTime.isEmpty {
                    Text(Self.shortTime(onkyo.trackTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                transportButton("backward.fill", small: true) { onkyo.previousTrack() }
                transportButton(onkyo.isPlaying ? "pause.fill" : "play.fill") { onkyo.playPause() }
                transportButton("forward.fill", small: true) { onkyo.nextTrack() }
            }
        }
    }

    private func transportButton(_ symbol: String, small: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .imageScale(small ? .small : .medium)
                .foregroundStyle(small ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .frame(width: 23, height: 21)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "00:00:39/00:03:40" → "0:39 / 3:40"
    private static func shortTime(_ ntm: String) -> String {
        let parts = ntm.split(separator: "/").map { part -> String in
            var p = String(part)
            if p.hasPrefix("00:") { p = String(p.dropFirst(3)) }
            if p.hasPrefix("0") && p.count > 4 { p = String(p.dropFirst()) }
            return p
        }
        return parts.joined(separator: " / ")
    }

    private func pickerRow(_ label: String, selection: Binding<String>,
                           options: [(String, String)]) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(options, id: \.0) { code, name in
                    Text(name).tag(code)
                }
                if !selection.wrappedValue.isEmpty,
                   !options.contains(where: { $0.0 == selection.wrappedValue }) {
                    Text(selection.wrappedValue).tag(selection.wrappedValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var inputRow: some View {
        HStack {
            Text("Input")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Input", selection: Binding(
                get: { onkyo.inputCode },
                set: { onkyo.setInput($0) }
            )) {
                ForEach(OnkyoInput.common) { input in
                    Text(input.name).tag(input.code)
                }
                if !onkyo.inputCode.isEmpty,
                   !OnkyoInput.common.contains(where: { $0.code == onkyo.inputCode }) {
                    Text(OnkyoInput.name(for: onkyo.inputCode)).tag(onkyo.inputCode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var settingsMenu: some View {
        Menu {
            Toggle("Start at Login", isOn: Binding(
                get: { onkyo.launchAtLogin },
                set: { onkyo.setLaunchAtLogin($0) }
            ))
            Button("Rescan Network") { onkyo.rescan() }
            Divider()
            Button("Quit OnkyoMac") { onkyo.quit() }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var disconnectedState: some View {
        VStack(spacing: 8) {
            if onkyo.isScanning {
                ProgressView()
                    .controlSize(.small)
                Text("Looking for receiver…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "hifireceiver")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No receiver found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Scan Again") { onkyo.rescan() }
                    .controlSize(.small)
            }
        }
    }
}
