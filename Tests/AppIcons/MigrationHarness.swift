import AppKit

// Only the dependencies outside AppIcon are replaced. Preferences are isolated;
// all catalogue, migration, availability, and selection behavior is production code.
extension UserDefaults {
    @MainActor static let iconTestDomain = ProcessInfo.processInfo.environment["TIMO_ICON_TEST_DOMAIN"]
        ?? "io.github.senommu.timo.icon-test.\(UUID().uuidString)"
    @MainActor static let timo = UserDefaults(suiteName: iconTestDomain)!
}
// Objective-C fixtures exercise the optional selector bridge, including older/future
// system classes with missing methods. The appearance value is never changed by refresh.
@MainActor final class IconAppearanceFixture: NSObject {
    static let current = IconAppearanceFixture()
    let appearance = "dark"
    var savedAppearance: String?
    @objc static func fetchCurrentIconAppearanceConfiguration() -> IconAppearanceFixture { current }
    @objc func save() { savedAppearance = appearance }
}
@MainActor final class IconAppearanceWithoutSave: NSObject {
    @objc static func fetchCurrentIconAppearanceConfiguration() -> NSObject { NSObject() }
}
@main @MainActor struct IconMigrationHarness {
    static func main() async {
        _ = NSApplication.shared
        defer {
            if !CommandLine.arguments.contains("--persistence") {
                UserDefaults.timo.removePersistentDomain(forName: UserDefaults.iconTestDomain)
            }
        }
        var failures = AppIcon.check().filter { !$0.1 }.map(\.0)
        func expect(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }
        AppIconPersistence.refreshDockIconCache(configurationClass: nil)
        AppIconPersistence.refreshDockIconCache(configurationClass: NSObject.self)
        AppIconPersistence.refreshDockIconCache(configurationClass: IconAppearanceWithoutSave.self)
        AppIconPersistence.refreshDockIconCache(configurationClass: IconAppearanceFixture.self)
        expect(IconAppearanceFixture.current.savedAppearance == "dark",
               "Dock refresh re-publishes the existing appearance without changing it")
        let embedded = URL(fileURLWithPath: "/Applications/Timo.app/Contents/XPCServices/io.github.senommu.timo.IconService.xpc")
        expect(AppIconPersistence.hostBundle(for: embedded)?.path == "/Applications/Timo.app",
               "helper targets only its containing app")
        for path in ["/Applications/Other.app/IconService.xpc",
                     "/Applications/Timo.app/Contents/Other/io.github.senommu.timo.IconService.xpc",
                     "/tmp/Contents/XPCServices/io.github.senommu.timo.IconService.xpc",
                     "/tmp/AppTranslocation/A/Timo.app/Contents/XPCServices/io.github.senommu.timo.IconService.xpc"] {
            expect(AppIconPersistence.hostBundle(for: URL(fileURLWithPath: path)) == nil,
                   "helper refuses an invalid or temporary host")
        }
        func luminance(_ image: NSImage?) -> CGFloat {
            guard let image else { return 1 }
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 128, pixelsHigh: 128,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                      bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(x: 0, y: 0, width: 128, height: 128))
            NSGraphicsContext.restoreGraphicsState()
            // Sample the tile away from the mushroom and its edge.
            let color = rep.colorAt(x: 28, y: 64)!.usingColorSpace(.sRGB)!
            return (color.redComponent + color.greenComponent + color.blueComponent) / 3
        }
        let packaged = CommandLine.arguments.contains("--packaged")
        if let index = CommandLine.arguments.firstIndex(of: "--persistence") {
            _ = NSApplication.shared
            let choice = CommandLine.arguments[index + 1]
            expect(AppIcon.isSandboxed == CommandLine.arguments.contains("--sandboxed"),
                   "fixture exercises the intended sandbox path")
            if choice == "cleanup" {
                if AppIcon.isSandboxed { _ = await AppIconPersistence.setIcon(nil) }
                else { _ = NSWorkspace.shared.setIcon(nil, forFile: Bundle.main.bundlePath, options: []) }
                UserDefaults.timo.removePersistentDomain(forName: UserDefaults.iconTestDomain)
                exit(0)
            }
            if choice == "restore" {
                expect(UserDefaults.timo.string(forKey: AppIcon.key) == "Timo",
                       "the saved mushroom icon survives a fresh process")
                AppIcon.restoreAtLaunch()
            } else if choice == "removed-custom" {
                UserDefaults.timo.set("Custom", forKey: AppIcon.key)
                AppIcon.restoreAtLaunch()
                expect(AppIcon.current == "Timo" && UserDefaults.timo.string(forKey: AppIcon.key) == "Timo",
                       "removed custom icons migrate to the mushroom")
            } else if choice == "invalid-data" {
                let stamped = await AppIconPersistence.setIcon(Data([0, 1, 2]))
                expect(!stamped, "helper refuses malformed image data")
            } else if choice != "verify" {
                AppIcon.apply(choice)
            }
            let persisted = await AppIcon.flushPersistence()
            expect(persisted, "last queued icon completes before checking Finder or quitting")
            UserDefaults.timo.synchronize()
            var finderInfo = [UInt8](repeating: 0, count: 32)
            let count = getxattr(Bundle.main.bundlePath, "com.apple.FinderInfo", &finderInfo, 32, 0, 0)
            let hasCustomIcon = count == 32 && finderInfo[8] & 0x04 != 0
            expect(hasCustomIcon,
                   "the bundle retains its selected icon after the first process exits (\(choice))")
            let preview = AppIcon.variants.first { $0.name == AppIcon.current }!.image
            let finder = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
            expect(abs(luminance(finder) - luminance(preview)) < 0.08,
                   "Finder immediately resolves the selected image, including in a fresh process (\(choice))")
            failures.forEach { print("FAIL: \($0)") }
            exit(failures.isEmpty ? 0 : 1)
        }
        expect(AppIcon.variants.count == 1 && AppIcon.variants.first?.name == "Timo",
               "exactly one mushroom preview loads with or without resources")
        let oldAssets = ["AppIcon-Dark", "AppIcon-Galaxy", "AppIcon-Candy", "AppIcon-Neon",
                         "AppIcon-FlutedGlass", "AppIcon-FlutedGlassDark", "AppIcon-Schoolbook", "AppIcon-Luminous"]
        if packaged {
            expect(NSImage(named: "AppIcon") != nil, "the mushroom loads from the bundled catalogue")
            expect(oldAssets.allSatisfy { NSImage(named: $0) == nil }, "no retired artwork remains in the catalogue")
            AppIcon.apply("Timo")
            expect(NSApp.applicationIconImage != nil, "applying Timo installs the mushroom in the live Dock")
            expect(abs(luminance(NSApp.applicationIconImage) - luminance(AppIcon.variants.first?.image)) < 0.01,
                   "Dock and Settings use the same mushroom artwork")
        } else {
            expect(NSImage(named: "AppIcon") == nil, "the bare binary exercises the missing-catalogue fallback")
        }
        let retired = ["Normal", "Dark", "Galaxy", "Candy", "Neon", "Fluted Glass", "Fluted Glass Dark",
                       "Schoolbook", "Luminous", "Default", "Glass", "Navy", "Custom", "unknown"]
        for legacy in retired {
            UserDefaults.timo.set(legacy, forKey: AppIcon.key)
            AppIcon.restoreAtLaunch()
            expect(UserDefaults.timo.string(forKey: AppIcon.key) == "Timo" && AppIcon.current == "Timo",
                   "\(legacy) migrates to Timo, including without assets")
        }
        AppIcon.apply("Timo")
        expect(UserDefaults.timo.string(forKey: AppIcon.key) == "Timo", "applying the mushroom saves its canonical name")
        _ = await AppIcon.flushPersistence()
        failures.forEach { print("FAIL: \($0)") }
        if !failures.isEmpty { exit(1) }
        print("PASS: single mushroom icon, migration, and \(packaged ? "bundled artwork" : "missing-asset fallback")")
    }
}
