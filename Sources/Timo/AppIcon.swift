import AppKit

/// The single mushroom icon shared by Settings, the Dock, and Finder.
/// macOS has no UIKit alternate-icon API, so the live tile uses applicationIconImage.
@MainActor enum AppIcon {
    /// Where the choice lives. `UserDefaults.timo`, so a test instance on its own data dir
    /// does not repaint the real app's Dock tile.
    static let key = "appIcon"

    /// The sole bundled artwork; retained as a catalogue for shared preview code.
    nonisolated static let catalogue: [(name: String, asset: String?)] = [("Timo", "AppIcon")]

    nonisolated static var `default`: String { "Timo" }

    /// All retired finishes and unknown saved values migrate to the mushroom.
    nonisolated static func canonicalName(_ name: String) -> String { `default` }

    /// Resource-free dev builds fall back to the shipped plate, independent of Finder stamps.
    private static let composed: NSImage = {
        // Finder may already hold the last selection. Read the shipped plate rather
        // than mistaking that persisted custom icon for the resource-free fallback.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) { return image }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }()

    /// Load the shipped artwork rather than a Finder icon stamped by an older build.
    static var variants: [(name: String, image: NSImage)] {
        catalogue.compactMap { row in
            if let asset = row.asset, let image = NSImage(named: asset) { return (row.name, image) }
            return row.name == `default` ? (row.name, composed) : nil
        }
    }

    /// The chosen icon's name — the default whenever nothing is chosen, or the chosen one is
    /// no longer in the bundle (an older release, a dev build).
    static var current: String {
        let saved = canonicalName(UserDefaults.timo.string(forKey: key) ?? `default`)
        return variants.contains { $0.name == saved } ? saved : `default`
    }

    /// Switch to the icon named `name`: the live Dock tile, the persisted choice, and — when
    /// the bundle can take it — the icon Finder keeps while Timo is quit. Returns whether
    /// a persistence request was queued; the first two always happen immediately.
    /// `flushPersistence` reports the helper result at quit or another durability boundary.
    @discardableResult
    static func apply(_ name: String) -> Bool {
        let name = canonicalName(name)
        guard let v = variants.first(where: { $0.name == name }) else { return false }
        let image: NSImage? = v.image
        NSApp.applicationIconImage = image
        MinimizedWindowIcon.apply(image)
        UserDefaults.timo.set(name, forKey: key)
        guard canPersist else { return false }
        if isSandboxed {
            // Send fixed-size raw pixels while still on the main actor.
            let data: Data?
            if let image {
                guard let encoded = AppIconPersistence.pixels(from: image) else {
                    enqueuePersistence { false }
                    return false
                }
                data = encoded
            } else { data = nil }
            enqueuePersistence { await AppIconPersistence.setIcon(data) }
        } else {
            enqueuePersistence { AppIconPersistence.stamp(image, at: Bundle.main.bundleURL) }
        }
        return true
    }

    private static let persistence = AppIconPersistenceQueue()
    static var persistencePending: Bool { persistence.pending }
    private static func enqueuePersistence(_ stamp: @escaping @MainActor () async -> Bool) {
        persistence.enqueue(stamp)
    }

    static func flushPersistence() async -> Bool { await persistence.flush() }

    /// Called once at launch, before the first window. The Dock tile belongs to the running
    /// process, so a chosen icon has to be put back every time — and `Updater` replaces the
    /// whole bundle on an in-place update, which takes any stamped Finder icon with it.
    /// Restore the explicit artwork even when the bundle still carries a previous stamp.
    static func restoreAtLaunch() {
        MinimizedWindowIcon.start()
        apply(`default`)
    }

    /// Read-only translocation mounts and bare SwiftPM binaries have no persistent target.
    static var canPersist: Bool { shouldPersist(bundlePath: Bundle.main.bundlePath) }

    nonisolated static var isSandboxed: Bool {
        NSHomeDirectory().contains("/Library/Containers/")
    }

    nonisolated static func shouldPersist(bundlePath: String) -> Bool {
        bundlePath.hasSuffix(".app") && !bundlePath.contains("/AppTranslocation/")
    }

    // MARK: Offline checks

    nonisolated static func check() -> [(String, Bool)] {
        [("an installed bundle can retain the icon through the sandbox's helper",
          shouldPersist(bundlePath: "/Applications/Timo.app")),
         ("a translocated copy is never stamped either — its mount is read-only and temporary",
          !shouldPersist(bundlePath: "/private/var/folders/q3/AppTranslocation/9F1/d/Timo.app")),
         ("the bare dev binary has no bundle to stamp",
          !shouldPersist(bundlePath: "/Users/ada/timo/.build/release/timo")),
         ("the mushroom is the sole bundled icon and default",
          `default` == "Timo" && catalogue.count == 1
              && catalogue.first?.name == "Timo" && catalogue.first?.asset == "AppIcon"),
         ("all retired finishes migrate to the mushroom",
          ["Default", "Custom", "Glass", "Navy", "Normal", "Dark", "Galaxy", "Candy", "Neon",
           "Fluted Glass", "Fluted Glass Dark", "Schoolbook", "Luminous", "unknown", "Timo"]
              .allSatisfy { canonicalName($0) == "Timo" })]
    }
}
