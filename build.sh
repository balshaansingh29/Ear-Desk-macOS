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


# Create fancy branded DMG installer if python3 and hdiutil are available
if command -v python3 &>/dev/null; then
    python3 -c '
import os, subprocess, time
dmg_path = "build/Ear-Desk-macOS-v1.3.0.dmg"
temp_dmg = "build/temp_installer.dmg"
vol_name = "Ear-Desk"
src_app = "build/Ear-Desk.app"
bg_img = "Resources/dmg_background.png"

if os.path.exists(temp_dmg): os.remove(temp_dmg)
if os.path.exists(dmg_path): os.remove(dmg_path)

subprocess.run(["hdiutil", "create", "-size", "120m", "-fs", "HFS+", "-volname", vol_name, "-ov", temp_dmg], check=True)
mount_output = subprocess.check_output(["hdiutil", "attach", temp_dmg, "-readwrite", "-noverify", "-noautoopen"]).decode()
mount_point = None
for line in mount_output.splitlines():
    if "/Volumes/" in line:
        mount_point = line.split("/Volumes/")[-1]
        mount_point = "/Volumes/" + mount_point.strip()
        break
if not mount_point: mount_point = f"/Volumes/{vol_name}"

try:
    subprocess.run(["cp", "-R", src_app, f"{mount_point}/Ear-Desk.app"], check=True)
    subprocess.run(["ln", "-s", "/Applications", f"{mount_point}/Applications"], check=True)
    bg_dir = f"{mount_point}/.background"
    os.makedirs(bg_dir, exist_ok=True)
    if os.path.exists(bg_img):
        subprocess.run(["cp", bg_img, f"{bg_dir}/background.png"], check=True)
        applescript = f"""
        tell application "Finder"
            tell disk "{vol_name}"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {{400, 100, 1060, 500}}
                set viewOptions to the icon view options of container window
                set arrangement of viewOptions to not arranged
                set icon size of viewOptions to 100
                set background picture of viewOptions to file ".background:background.png"
                set position of item "Ear-Desk.app" of container window to {{170, 200}}
                set position of item "Applications" of container window to {{490, 200}}
                close
                open
                update without registering applications
                delay 1
                close
            end tell
        end tell
        """
        subprocess.run(["osascript", "-e", applescript])
finally:
    subprocess.run(["hdiutil", "detach", mount_point, "-force"])

subprocess.run(["hdiutil", "convert", temp_dmg, "-format", "UDZO", "-imagekey", "zlib-level=9", "-o", dmg_path], check=True)
if os.path.exists(temp_dmg): os.remove(temp_dmg)
'
fi
