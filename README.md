<div align="center">

<img src="docs/icon.png" width="128" alt="OnkyoMac icon">

# OnkyoMac

**Onkyo receiver control that feels built into macOS.**

A tiny native menu bar app for your Onkyo AV receiver — power, volume, inputs, HDMI output routing, sound modes and now playing, styled like Control Center. No cloud, no account, no Electron. One tiny binary.

[![Latest release](https://img.shields.io/github/v/release/inakizamores/OnkyoMac?label=Download&color=blue)](https://github.com/inakizamores/OnkyoMac/releases/latest)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)](#requirements)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-native-black)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)](Sources/OnkyoMac)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

---

## Install

**[⬇ Download OnkyoMac.dmg](https://github.com/inakizamores/OnkyoMac/releases/latest/download/OnkyoMac.dmg)** — open it, drag OnkyoMac into Applications, launch it.

> **First launch:** OnkyoMac is open source and not notarized by Apple (no paid developer account), so macOS will show *"Apple could not verify OnkyoMac"*. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** — needed exactly once.

Prefer to skip that dialog? This one-liner downloads, installs and launches it directly:

```bash
curl -fsSL -o /tmp/OnkyoMac.zip https://github.com/inakizamores/OnkyoMac/releases/latest/download/OnkyoMac.zip && ditto -xk /tmp/OnkyoMac.zip /Applications && xattr -dr com.apple.quarantine /Applications/OnkyoMac.app && open /Applications/OnkyoMac.app
```

When macOS asks for **Local Network** access, click **Allow** — that's how OnkyoMac finds your receiver. That's the entire setup.

## Features

- ⚡ **Power** — turn the receiver on and off from the menu bar (works from network standby)
- 🎚️ **Volume & mute** — Control-Center-style capsule slider, mute on the speaker glyph
- 🎛️ **Input selection** — TV, BD/DVD, CBL/SAT, Game, PC, CD, Bluetooth, Network, USB, AUX, FM, AM
- 📺 **HDMI output routing** — switch between Main, Sub, or Main + Sub outputs (TV vs. projector)
- 🎵 **Now Playing** — title, artist, album art and live progress for Network/Bluetooth/USB sources, with play/pause/skip
- 🔊 **Sound modes** — Stereo, Direct, All Ch Stereo, Full Mono, Dolby Surround, DTS Neural:X
- 🚀 **Start at Login** — lives quietly in the menu bar, ready before you are

## Design

OnkyoMac is built to disappear into macOS:

- **Native everywhere** — SwiftUI `MenuBarExtra`, system panel chrome, SF Symbols, system materials and semantic colors. Dark mode, accent colors and accessibility settings just work.
- **Real-time, zero polling** — speaks eISCP (Integra Serial Control Protocol) over TCP; the receiver *pushes* every state change, so turning the volume knob on the unit moves the slider live.
- **Light for real** — single arm64 binary, idle at 0% CPU. It connects only while the panel is open; closed, it does nothing at all.
- **Local only** — talks directly to the receiver on port 60128. Nothing ever leaves your network. No analytics, no accounts, no telemetry.
- **Instant** — the receiver's address is cached after first discovery; reconnecting is immediate, UDP broadcast discovery is the fallback.

## Requirements

- macOS 14 Sonoma or later (Apple Silicon)
- A network-connected Onkyo (or Integra / recent Pioneer) receiver that speaks eISCP
- **Network Standby** enabled on the receiver if you want power-on to work while it's off

Developed and tested against an Onkyo HT-R695; the eISCP command set is shared across most Onkyo/Integra models (and Pioneer models from 2016 on), so others should work — controls the receiver doesn't support are simply ignored by it.

## Build from source

Only Xcode Command Line Tools needed (`xcode-select --install`):

```bash
git clone https://github.com/inakizamores/OnkyoMac.git
cd OnkyoMac
./build.sh --install
```

`./build.sh` builds `build/OnkyoMac.app`; `--install` also copies it to /Applications and launches it. `./release.sh` produces the distributable `.dmg` and `.zip`. Releases are built automatically by GitHub Actions when a `v*` tag is pushed.

## License

[MIT](LICENSE) — do whatever you like with it.
