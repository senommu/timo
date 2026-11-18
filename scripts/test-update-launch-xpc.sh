#!/bin/bash
# Signed, headless XPC/browser sandbox fixtures; never starts the user's browser.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${SIGN_ID:?Set SIGN_ID to the Timo Developer ID signing identity}"
WORK=$(mktemp -d "$HOME/Downloads/timo-installer-xpc.XXXXXX")
PROBE_NAME="Timo-security-check-$(uuidgen)"
SYSTEM_PROBE="/Applications/$PROBE_NAME"
USER_ROOT="$HOME/Applications"
USER_ROOT_CREATED=0
if [ ! -d "$USER_ROOT" ]; then mkdir "$USER_ROOT"; USER_ROOT_CREATED=1; fi
USER_PROBE="$USER_ROOT/$PROBE_NAME"
cleanup() {
  python3 scripts/run-updater-test-client.py "$WORK" --cleanup
  rm -rf "$WORK" "$SYSTEM_PROBE" "$USER_PROBE"
  if [ "$USER_ROOT_CREATED" = 1 ]; then rmdir "$USER_ROOT" 2>/dev/null || true; fi
}
trap cleanup EXIT
mkdir "$SYSTEM_PROBE" "$USER_PROBE"
echo -n canary > "$SYSTEM_PROBE/read"
echo -n canary > "$USER_PROBE/read"
APP="$WORK/templates/Timo.app"
SERVICE="$APP/Contents/XPCServices/io.github.senommu.timo.UpdateInstaller.xpc"
mkdir -p "$APP/Contents/MacOS" "$SERVICE/Contents/MacOS"
cp installer/UpdateInstaller-Info.plist "$SERVICE/Contents/Info.plist"
cat > "$WORK/main.swift" <<SWIFT
import Foundation
let service = InstallerService(applicationsDirectories: [URL(fileURLWithPath: "$WORK")])
let listener = NSXPCListener.service()
listener.delegate = service
listener.resume()
SWIFT
xcrun swiftc Sources/Timo/BundleReplacement.swift Sources/Timo/UpdateVersion.swift Sources/Timo/UpdateInstaller.swift \
  Sources/UpdateInstaller/UpdateInstallation.swift Sources/UpdateInstaller/InstallerService.swift \
  "$WORK/main.swift" -o "$SERVICE/Contents/MacOS/TimoUpdateInstaller"
xcrun swiftc Sources/Timo/UpdateInstaller.swift Tests/UpdateLaunchClient/main.swift -o "$APP/Contents/MacOS/Timo"
xcrun swiftc Sources/Timo/BundleReplacement.swift Tests/UpdateLaunchDriver/main.swift -o "$WORK/install"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.senommu.timo</string>
<key>CFBundleExecutable</key><string>Timo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
</dict></plist>
PLIST
codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$SERVICE"
codesign --force --options runtime --timestamp --entitlements "${TIMO_TEST_ENTITLEMENTS:-Timo.entitlements}" --sign "$SIGN_ID" "$APP"
python3 scripts/run-updater-test-client.py "$WORK" -- "$APP/Contents/MacOS/Timo" --access "$SYSTEM_PROBE" "$USER_PROBE"
python3 scripts/run-updater-test-client.py "$WORK" -- "$APP/Contents/MacOS/Timo" --wrong-target
cp -R "$APP" "$WORK/old.app"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 2.0.0' "$APP/Contents/Info.plist"
codesign --force --options runtime --timestamp --entitlements Timo.entitlements --sign "$SIGN_ID" "$APP"
mkdir "$WORK/healthy" "$WORK/rollback"
for SCENE in healthy rollback; do
  TARGET="$WORK/$SCENE/Timo.app"
  cp -R "$WORK/old.app" "$TARGET"
  "$WORK/install" "$APP" "$TARGET"
  if [ "$SCENE" = rollback ]; then
    python3 scripts/run-updater-test-client.py "$WORK" -- "$TARGET/Contents/MacOS/Timo" --crash
    python3 scripts/run-updater-test-client.py "$WORK" --cleanup
    python3 scripts/run-updater-test-client.py "$WORK" -- "$TARGET/Contents/MacOS/Timo" --rollback
    python3 scripts/run-updater-test-client.py "$WORK" -- "$TARGET/Contents/MacOS/Timo" --recover-orphans
  else
    python3 scripts/run-updater-test-client.py "$WORK" -- "$TARGET/Contents/MacOS/Timo" --healthy
  fi
done
mkdir "$WORK/displaced"
TARGET="$WORK/displaced/Timo.app"
cp -R "$WORK/old.app" "$TARGET"
python3 scripts/run-updater-test-client.py "$WORK" -- "$TARGET/Contents/MacOS/Timo" --displaced "$WORK/ready" "$WORK/go" &
CLIENT=$!
for ATTEMPT in $(seq 1 200); do
  if [ -f "$WORK/ready" ]; then break; fi
  sleep 0.1
done
test -f "$WORK/ready"
"$WORK/install" "$APP" "$TARGET"
touch "$WORK/go"
wait "$CLIENT"
python3 scripts/run-updater-test-client.py "$WORK" -- "$TARGET/Contents/MacOS/Timo" --healthy
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier io.github.senommu.timo.unrelated-test' "$APP/Contents/Info.plist"
codesign --force --options runtime --timestamp --entitlements Timo.entitlements --sign "$SIGN_ID" "$APP"
python3 scripts/run-updater-test-client.py "$WORK" -- "$APP/Contents/MacOS/Timo" --unauthorized
