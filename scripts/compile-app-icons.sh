#!/bin/bash
# Compile the single mushroom icon into the native asset catalogue.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST="${1:-AppIcons/Prebuilt}"
mkdir -p "$DEST"
INFO="$(mktemp -t timo-icon-info)"
trap 'rm -f "$INFO"' EXIT
cp AppIcons/Timo.svg AppIcons/AppIcon.icon/Assets/timo-mushroom.svg
xcrun actool AppIcons/AppIcon.icon AppIcons/Static.xcassets --compile "$DEST" --app-icon AppIcon \
  --platform macosx --minimum-deployment-target 26.0 \
  --output-partial-info-plist "$INFO"
