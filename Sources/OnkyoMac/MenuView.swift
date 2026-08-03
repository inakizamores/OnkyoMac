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
                inputRow
                    .disabled(!onkyo.powerOn)
                    .opacity(onkyo.powerOn ? 1 : 0.4)
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
