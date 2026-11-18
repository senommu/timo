#!/bin/bash
# Validate real signed/notarized copies without touching an installed Timo.
set -euo pipefail
cd "$(dirname "$0")/.."
APP="${1:-/Applications/Timo.app}"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/timo-installer-tests.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc Sources/Timo/BundleReplacement.swift Sources/Timo/UpdateVersion.swift Sources/Timo/UpdateInstaller.swift \
  Sources/UpdateInstaller/UpdateInstallation.swift Tests/UpdatePreparation/main.swift \
  -o "$WORK/preparation-check"
"$WORK/preparation-check"
xcrun swiftc Sources/Timo/BundleReplacement.swift Sources/Timo/UpdateVersion.swift Sources/Timo/UpdateInstaller.swift \
  Sources/UpdateInstaller/UpdateInstallation.swift Tests/UpdateInstaller/main.swift \
  -o "$WORK/check"
if [ "$#" -gt 0 ]; then shift; fi
"$WORK/check" "$APP" "$@"
