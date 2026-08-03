#!/bin/zsh
# Builds release artifacts: dist/OnkyoMac.dmg and dist/OnkyoMac.zip
set -euo pipefail
cd "$(dirname "$0")"

./build.sh

mkdir -p dist
rm -f dist/OnkyoMac.dmg dist/OnkyoMac.zip

ditto -c -k --keepParent build/OnkyoMac.app dist/OnkyoMac.zip

# Styled installer window: background + Finder layout template (Support/dmg).
STAGE=$(mktemp -d)
cp -R build/OnkyoMac.app "$STAGE/OnkyoMac.app"
ln -s /Applications "$STAGE/Applications"
mkdir "$STAGE/.background"
cp Support/dmg/background.tiff "$STAGE/.background/background.tiff"
cp Support/dmg/DS_Store "$STAGE/.DS_Store"
hdiutil create -volname "OnkyoMac" -srcfolder "$STAGE" -ov -format UDZO -quiet dist/OnkyoMac.dmg
rm -rf "$STAGE"

echo "Release artifacts ready:"
du -h dist/OnkyoMac.dmg dist/OnkyoMac.zip
