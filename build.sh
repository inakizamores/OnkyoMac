#!/bin/zsh
# Builds OnkyoMac.app (arm64 release). Use --install to copy to /Applications and launch.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/OnkyoMac.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/OnkyoMac "$APP/Contents/MacOS/OnkyoMac"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - "$APP" 2>/dev/null

echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x OnkyoMac 2>/dev/null || true
    sleep 0.4
    rm -rf /Applications/OnkyoMac.app
    cp -R "$APP" /Applications/OnkyoMac.app
    open /Applications/OnkyoMac.app
    echo "Installed to /Applications/OnkyoMac.app and launched"
fi
