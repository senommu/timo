import AppKit
import XCTest
@testable import timo

@MainActor final class TabOrderingTests: XCTestCase {
    func testReorderingPublishesCompleteListsWithoutRedundantUpdates() async {
        TestEnvironment.prepare()
        _ = NSApplication.shared
        for (name, passed) in TabOrderingChecks.check() {
            XCTAssertTrue(passed, name)
        }
    }
}
