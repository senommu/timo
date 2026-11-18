#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d "${TMPDIR:-/tmp}/timo-updater-relaunch-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc Sources/Timo/UpdateInstaller.swift Sources/Timo/UpdateRelaunch.swift Tests/UpdaterRelaunch/main.swift -o "$WORK/check"
"$WORK/check"
