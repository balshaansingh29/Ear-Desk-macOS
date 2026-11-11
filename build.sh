#!/bin/bash
# Builds a native Apple-silicon (arm64) Nothing X.app. Run on a Mac with Xcode or the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

swift test                                   # protocol golden-vector tests
swift build -c release --arch arm64

APP="build/Nothing X.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/arm64-apple-macosx/release/NothingX "$APP/Contents/MacOS/NothingX"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS will grant the Bluetooth permission prompt. Use your Developer ID to distribute.
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
file "$APP/Contents/MacOS/NothingX"