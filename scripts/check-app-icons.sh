#!/bin/bash
# Exercise the single production mushroom icon with and without bundled resources.
set -euo pipefail
cd "$(dirname "$0")/.."
FIXTURE="$(mktemp -d -t timo-icon-check)"
trap 'rm -rf "$FIXTURE"' EXIT
xcrun swiftc -swift-version 6 Sources/Timo/AppIcon.swift Sources/Timo/RasterImage.swift Sources/Timo/MinimizedWindowIcon.swift Sources/Timo/AppIconPersistence.swift Tests/AppIcons/MigrationHarness.swift \
  -o "$FIXTURE/Check"
"$FIXTURE/Check"
# A translocation-shaped fixture path prevents Finder stamping during selections.
BUNDLE="$FIXTURE/AppTranslocation/IconCheck.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$FIXTURE/Check" "$BUNDLE/Contents/MacOS/Check"
cp AppIcons/Prebuilt/Assets.car AppIcons/Prebuilt/AppIcon.icns "$BUNDLE/Contents/Resources/"
cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Check</string>
<key>CFBundleIdentifier</key><string>io.github.senommu.timo.icon-check</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconName</key><string>AppIcon</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
"$BUNDLE/Contents/MacOS/Check" --packaged

# Exercise on-disk persistence across separate processes in a writable fixture only.
export TIMO_ICON_TEST_DOMAIN="io.github.senommu.timo.icon-test.$(basename "$FIXTURE")"
PERSIST="$FIXTURE/Persistence.app"
cp -R "$BUNDLE" "$PERSIST"
for action in Timo verify restore verify invalid-data removed-custom verify; do
  "$PERSIST/Contents/MacOS/Check" --persistence "$action"
done

# The production sandbox must use the embedded helper, including ad-hoc local builds.
SANDBOX="$FIXTURE/Sandbox.app"
cp -R "$BUNDLE" "$SANDBOX"
SERVICE="$SANDBOX/Contents/XPCServices/io.github.senommu.timo.IconService.xpc"
mkdir -p "$SERVICE/Contents/MacOS"
cp installer/IconService-Info.plist "$SERVICE/Contents/Info.plist"
xcrun swiftc -swift-version 6 Sources/Timo/AppIconPersistence.swift Sources/IconService/main.swift \
  -o "$SERVICE/Contents/MacOS/TimoIconService"
codesign --force --sign - "$SERVICE"
codesign --force --entitlements Timo.entitlements --sign - "$SANDBOX"
for action in Timo verify restore verify invalid-data removed-custom verify; do
  "$SANDBOX/Contents/MacOS/Check" --sandboxed --persistence "$action"
done
"$SANDBOX/Contents/MacOS/Check" --sandboxed --persistence cleanup
"$PERSIST/Contents/MacOS/Check" --persistence cleanup
codesign --verify --deep --strict "$SANDBOX"
echo "PASS: the mushroom icon persists after exit in sandboxed and unsandboxed bundles"
