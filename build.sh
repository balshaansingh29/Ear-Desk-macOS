#!/bin/bash
# Builds a native Apple-silicon (arm64) Ear-Desk.app. Run on a Mac with Xcode or the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

swift test                                   # protocol golden-vector tests
swift build -c release --arch arm64

BIN_DIR=$(swift build --show-bin-path -c release --arch arm64)

APP="build/Ear-Desk.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/EarDesk" "$APP/Contents/MacOS/EarDesk"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
if [ -d Resources/Products ]; then
    mkdir -p "$APP/Contents/Resources/Products"
    cp Resources/Products/*.png "$APP/Contents/Resources/Products/"
fi

# Ad-hoc sign so macOS will grant the Bluetooth permission prompt. Use your Developer ID to distribute.
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
file "$APP/Contents/MacOS/EarDesk"
