#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
swiftc -swift-version 6 -parse-as-library Sources/Timo/CloudAI.swift Sources/Timo/AIConnections.swift Sources/Timo/ChatGPTOAuth.swift Sources/Timo/BrowserAI.swift Tests/BrowserAIRoutingHarness.swift -o "$fixture/check"
"$fixture/check"
