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
if [ -d Resources/AppIcons ]; then
    mkdir -p "$APP/Contents/Resources/AppIcons"
    cp Resources/AppIcons/*.png "$APP/Contents/Resources/AppIcons/"
    cp Resources/AppIcons/*.icns "$APP/Contents/Resources/AppIcons/"
fi

# Ad-hoc sign so macOS will grant the Bluetooth permission prompt. Use your Developer ID to distribute.
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
file "$APP/Contents/MacOS/EarDesk"


# Create fancy branded DMG installer if python3 and hdiutil are available
if command -v python3 &>/dev/null; then
    python3 -c '
import os, subprocess, time, glob

dmg_path = "build/Ear-Desk-macOS-v1.7.0.dmg"
temp_dmg = "build/temp_installer.dmg"
vol_name = "Ear-Desk"
src_app = "build/Ear-Desk.app"
bg_img = "Resources/dmg_background.png"

# Unmount any existing Ear-Desk mounts first
mount_list = subprocess.run(["mount"], capture_output=True, text=True).stdout
for line in mount_list.splitlines():
    if "/Volumes/Ear-Desk" in line:
        parts = line.split(" on ")
        if len(parts) > 1:
            mp = parts[1].split(" (")[0]
            subprocess.run(["diskutil", "unmount", "force", mp], check=False)

if os.path.exists(temp_dmg): os.remove(temp_dmg)
if os.path.exists(dmg_path): os.remove(dmg_path)

# Always copy light icon to app bundle before packaging DMG so app inside DMG is Light
app_icon_light = "Resources/AppIcons/AppIcon-Light.icns"
if os.path.exists(app_icon_light):
    subprocess.run(["cp", app_icon_light, f"{src_app}/Contents/Resources/AppIcon.icns"], check=False)

# Re-sign app with light icon
subprocess.run(["codesign", "--force", "--deep", "--sign", "-", src_app], check=False)

# Create 140MB temp dmg
subprocess.run(["hdiutil", "create", "-size", "140m", "-fs", "HFS+", "-volname", vol_name, "-ov", temp_dmg], check=True)
mount_output = subprocess.check_output(["hdiutil", "attach", temp_dmg, "-readwrite", "-noverify", "-noautoopen"]).decode()
mount_point = None
for line in mount_output.splitlines():
    if "/Volumes/" in line:
        mount_point = "/Volumes/" + line.split("/Volumes/")[-1].strip()
        break
if not mount_point: mount_point = f"/Volumes/{vol_name}"

disk_name = os.path.basename(mount_point)

try:
    # Copy app and symlink Applications
    subprocess.run(["cp", "-R", src_app, f"{mount_point}/Ear-Desk.app"], check=True)
    subprocess.run(["ln", "-s", "/Applications", f"{mount_point}/Applications"], check=True)
    
    # 1. Volume Icon: Set DMG volume icon explicitly to AppIcon-Light
    if os.path.exists(app_icon_light):
        vol_icon_dst = f"{mount_point}/.VolumeIcon.icns"
        subprocess.run(["cp", app_icon_light, vol_icon_dst], check=True)
        if os.path.exists("/usr/bin/SetFile"):
            subprocess.run(["/usr/bin/SetFile", "-a", "C", mount_point], check=False)
            subprocess.run(["/usr/bin/SetFile", "-a", "V", vol_icon_dst], check=False)
    
    # 2. Background Image
    bg_dir = f"{mount_point}/.background"
    os.makedirs(bg_dir, exist_ok=True)
    if os.path.exists(bg_img):
        subprocess.run(["cp", bg_img, f"{bg_dir}/background.png"], check=True)
        bg_posix = f"{bg_dir}/background.png"
        
        # Position window bounds {300, 200, 960, 620} -> exactly 660 x 420
        # Ear-Desk.app centered at (165, 205)
        # Applications centered at (495, 205)
        applescript = f"""
        set bgFile to POSIX file "{bg_posix}"
        tell application "Finder"
            tell disk "{disk_name}"
                open
                delay 1
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {{300, 200, 960, 620}}
                set theOptions to the icon view options of container window
                set arrangement of theOptions to not arranged
                set icon size of theOptions to 110
                set text size of theOptions to 12
                set label position of theOptions to bottom
                set background picture of theOptions to bgFile
                delay 1
                set position of item "Ear-Desk.app" of container window to {{165, 205}}
                set position of item "Applications" of container window to {{495, 205}}
                update without registering applications
                delay 2
                close
            end tell
        end tell
        """
        res = subprocess.run(["osascript", "-e", applescript], capture_output=True, text=True)
        print("Finder config result:", res.stdout, res.stderr)
        time.sleep(1)

    subprocess.run(["sync"])
finally:
    subprocess.run(["hdiutil", "detach", mount_point, "-force"], check=False)
    time.sleep(2)

subprocess.run(["hdiutil", "convert", temp_dmg, "-format", "UDZO", "-imagekey", "zlib-level=9", "-o", dmg_path], check=True)
if os.path.exists(temp_dmg): os.remove(temp_dmg)
print("DMG build completed successfully with Light icon inside and out!")
'
fi
