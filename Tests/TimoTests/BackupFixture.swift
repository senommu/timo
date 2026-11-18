import XCTest
import SQLite3
@testable import timo

@MainActor final class BackupFixture {
    let root: URL
    let domain: String
    let defaults: UserDefaults
    var library: BackupLibrary { BackupLibrary(directory: root, defaults: defaults, domain: domain) }
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("timo-backup-test-\(UUID())")
        domain = "timo.backup.test.\(UUID())"
        defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func cleanup() {
        UserDefaults.dropScratchSuite(domain)
        try? FileManager.default.removeItem(at: root)
    }
    @discardableResult func seed() -> ProfileManager { ProfileManager(directory: root, sandboxed: true) }
    func write<T: Encodable>(_ value: T, name: String) throws {
        try JSONEncoder().encode(value).write(to: root.appendingPathComponent(name))
    }
    func database(_ profile: UUID) -> Store { Store(path: ProfileManager.dbURL(for: profile, in: root).path) }
}
