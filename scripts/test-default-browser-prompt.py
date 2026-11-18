#!/usr/bin/env python3
"""Check the real app packager's default-browser policy without signing identities."""

import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def executable(path, body):
    path.write_text("#!/bin/bash\nset -eu\n" + body)
    path.chmod(0o755)


with tempfile.TemporaryDirectory(prefix="timo-default-browser-") as directory:
    fixture = Path(directory)
    shutil.copy2(ROOT / "make-app.sh", fixture / "make-app.sh")
    (fixture / "installer").mkdir()
    shutil.copy2(ROOT / "installer/UpdateInstaller-Info.plist", fixture / "installer")
    shutil.copy2(ROOT / "installer/IconService-Info.plist", fixture / "installer")
    shutil.copy2(ROOT / "Timo.entitlements", fixture)
    for configuration in ("debug", "release"):
        binary = fixture / ".build" / configuration / "timo"
        binary.parent.mkdir(parents=True)
        executable(binary, "exit 0\n")
        fonts = binary.parent / "Timo_timo.bundle/Contents/Resources/EaselFonts"
        shutil.copytree(ROOT / "Sources/Timo/EaselFonts", fonts)

    # Replace only toolchain/signing boundaries; the real shell script emits the plist.
    commands = fixture / "commands"
    commands.mkdir()
    for name in ("BundleReplacement.swift", "UpdateVersion.swift", "UpdateInstaller.swift",
                 "UpdateRelaunch.swift", "AppIconPersistence.swift"):
        destination = fixture / "Sources/Timo" / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / "Sources/Timo" / name, destination)
    shutil.copytree(ROOT / "Sources/UpdateInstaller", fixture / "Sources/UpdateInstaller")
    shutil.copytree(ROOT / "Sources/IconService", fixture / "Sources/IconService")
    helper_log = fixture / "helper-build.log"
    build_log = fixture / "swift-build.log"
    executable(commands / "swift", 'printf "%s\\n" "$*" >> "$TIMO_SWIFT_BUILD_LOG"\n')
    executable(commands / "xcrun", """
printf '%s\\n' "$*" >> "$TIMO_HELPER_BUILD_LOG"
if [ "${TIMO_HELPER_BUILD_FAIL:-}" = 1 ]; then exit 1; fi
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then
    shift
    printf '#!/bin/bash\\nexit 0\\n' > "$1"
    chmod +x "$1"
  fi
  shift
done
""")
    executable(commands / "codesign", """
if [ "$1" = -d ] && [ "${@: -1}" = Timo.app ]; then
  echo 'com.apple.security.app-sandbox temporary-exception.files.absolute-path.read-only temporary-exception.files.home-relative-path.read-only'
fi
""")
    cases = [
        ("debug", "", "1.2.3", False),
        ("release", "", "1.2.3", False),
        ("release", "-", "1.2.3", False),
        ("debug", "Developer ID Application: Fixture", "1.2.3", False),
        ("release", "Developer ID Application: Fixture", "1.2.3-rc1", False),
        ("release", "Developer ID Application: Fixture", "1.2.3", True),
    ]
    for configuration, identity, version, expected in cases:
        environment = {**os.environ, "PATH": str(commands) + os.pathsep + os.environ["PATH"],
                       "TMPDIR": str(fixture), "SIGN_ID": identity,
                       "TIMO_VERSION": version, "TIMO_BUILD": "1", "TIMO_SWIFT_BUILD_LOG": str(build_log), "TIMO_HELPER_BUILD_LOG": str(helper_log)}
        subprocess.run(["bash", str(fixture / "make-app.sh"), configuration],
                       env=environment, check=True, capture_output=True, text=True)
        with (fixture / "Timo.app/Contents/Info.plist").open("rb") as file:
            info = plistlib.load(file)
        actual = info.get("TimoDefaultBrowserPromptEnabled")
        assert actual is expected, (configuration, identity, version, expected, actual)
        bundled = fixture / "Timo.app/Contents/Resources/Timo_timo.bundle/Contents/Resources/EaselFonts"
        for font in ("Excalifont-Regular.ttf", "Nunito-Regular.ttf", "ComicShanns-Regular.ttf"):
            assert (bundled / font).read_bytes() == (ROOT / "Sources/Timo/EaselFonts" / font).read_bytes()

    assert len(build_log.read_text().splitlines()) == len(cases), "Default packaging still compiles the app"
    build_log.unlink()
    environment.update(SIGN_ID="", TIMO_VERSION="1.2.3")
    subprocess.run(["bash", str(fixture / "make-app.sh"), "debug", "--skip-app-build"],
                   env=environment, check=True, capture_output=True, text=True)
    assert not build_log.exists(), "Prebuilt CI packaging must not invoke a second SwiftPM engine"
    assert (fixture / "Timo.app/Contents/MacOS/Timo").read_bytes() == (fixture / ".build/debug/timo").read_bytes()
    result = subprocess.run(["bash", str(fixture / "make-app.sh"), "release", "--skip-app-build"],
                            env=environment, capture_output=True)
    assert result.returncode != 0, "Release packaging must retain its build validation"
    # Re-enter the real CI packager, changing only compiler/signing boundaries.
    environment["TIMO_CI_TOOLCHAIN_KEY"] = "fixture-toolchain"
    def assemble():
        helper_log.write_text("")
        subprocess.run(["bash", str(fixture / "make-app.sh"), "debug", "--skip-app-build"],
                       env=environment, check=True, capture_output=True, text=True)
        return helper_log.read_text().splitlines()

    assert len(assemble()) == 2, "First keyed assembly compiles both helpers"
    assert len(assemble()) == 0, "Unchanged helpers must reuse content/toolchain-matching products"
    changed = fixture / "Sources/UpdateInstaller/InstallerService.swift"
    changed.write_text(changed.read_text() + "\n// changed fixture input\n")
    calls = assemble()
    assert len(calls) == 1 and "TimoUpdateInstaller" in calls[0], calls
    environment["TIMO_CI_TOOLCHAIN_KEY"] = "other-toolchain"
    assert len(assemble()) == 2, "Toolchain changes invalidate both helpers"
    (fixture / ".build/debug/TimoIconService").unlink()
    calls = assemble()
    assert len(calls) == 1 and "TimoIconService" in calls[0], calls
    (fixture / ".build/debug/TimoIconService").chmod(0o644)
    calls = assemble()
    assert len(calls) == 1 and "TimoIconService" in calls[0], calls
    script = fixture / "make-app.sh"
    script.write_text(script.read_text() + "\n# changed packaging policy\n")
    assert len(assemble()) == 2, "Compiler/packaging policy changes invalidate both helpers"
    environment.update(TIMO_CI_TOOLCHAIN_KEY="failed-toolchain", TIMO_HELPER_BUILD_FAIL="1")
    try:
        assemble()
        raise AssertionError("Failed helper compilation must fail assembly")
    except subprocess.CalledProcessError:
        pass
    assert not (fixture / ".build/debug/TimoUpdateInstaller.inputs.sha256").exists()
    environment.pop("TIMO_HELPER_BUILD_FAIL")
    assert len(assemble()) == 2, "A failed compiler must never publish a reusable stamp"
    environment.pop("TIMO_CI_TOOLCHAIN_KEY")
    assert len(assemble()) == 2, "A missing trusted CI toolchain key disables helper reuse"

    (fixture / ".build/debug/timo").unlink()
    result = subprocess.run(["bash", str(fixture / "make-app.sh"), "debug", "--skip-app-build"],
                            env=environment, capture_output=True)
    assert result.returncode != 0, "Prebuilt packaging requires an existing executable"
    assert not build_log.exists()

print("PASS: prompt policy; default build; CI helper content/toolchain reuse and failure invalidation")
