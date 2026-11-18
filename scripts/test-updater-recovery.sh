#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d "${TMPDIR:-/tmp}/timo-updater-recovery-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc Sources/Timo/BundleReplacement.swift Tests/UpdaterRecovery/main.swift -o "$WORK/check"
"$WORK/check"
