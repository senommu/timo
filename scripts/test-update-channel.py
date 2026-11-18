#!/usr/bin/env python3
"""Run the production channel policy without AppKit or browser/profile state."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="timo-channel-tests-") as directory:
    binary = Path(directory) / "channel-tests"
    subprocess.run(["swiftc", str(root / "Sources/Timo/UpdateVersion.swift"),
                    str(root / "Sources/Timo/UpdateChannel.swift"),
                    str(root / "Tests/UpdateChannel/main.swift"), "-o", str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
