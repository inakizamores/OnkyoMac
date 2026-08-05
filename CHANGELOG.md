# Changelog

## 1.2.0 — V1 complete
- Real UI screenshots, fully rewritten documentation, polished release notes
- Screenshot rendering mode (`--render-screenshots`) producing the README image from the actual SwiftUI views

## 1.1.x
- Receiver-provided input list (NRI): real labels like STRM BOX, custom renames, per-model accuracy
- Now Playing with album art, transport controls, live progress
- HDMI output routing (Main / Sub / Main + Sub) and sound-mode picker
- Subtle audio format readout (codec → mode → channels)
- Power-on state re-reads across the receiver's boot window
- Damped horizontal-swipe volume; smooth fill animation; instant populated panel
- Corrected sound-mode table (Theater-Dimensional 0D, Full Mono 13) — verified on hardware

## 1.0.x
- Initial release: power, volume/mute, input selection over eISCP with push updates
- Styled DMG installer; automated releases via GitHub Actions (macOS 26 SDK guard)
