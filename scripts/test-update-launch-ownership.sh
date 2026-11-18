#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d "${TMPDIR:-/tmp}/timo-launch-owner-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc Sources/Timo/BundleReplacement.swift Tests/UpdateLaunchOwnership/main.swift -o "$WORK/check"
"$WORK/check"
