import XCTest
@testable import timo

@MainActor final class BrowserAIStateMemoTests: XCTestCase {
    func testStateFollowsStoredBytesAfterMemoisation() {
        TestEnvironment.prepare()
        let key = AIConnections.preferenceKey
        let previous = UserDefaults.timo.data(forKey: key)
        defer {
            if let previous { UserDefaults.timo.set(previous, forKey: key) } else { UserDefaults.timo.removeObject(forKey: key) }
        }
        var first = AIConnections(); first.connections = [AIConnection(provider: .groq)]
        first.save(UserDefaults.timo)
        XCTAssertEqual(BrowserAI.state, first)
        XCTAssertEqual(BrowserAI.state, first, "A repeated read returns the same decoded value")
        var second = AIConnections(); second.connections = [AIConnection(provider: .custom), AIConnection(provider: .groq)]
        second.save(UserDefaults.timo)
        XCTAssertEqual(BrowserAI.state, second, "New bytes must replace the memoised state")
        UserDefaults.timo.set(Data("not json".utf8), forKey: key)
        XCTAssertEqual(BrowserAI.state, AIConnections(), "Damaged bytes decode to empty, not the stale memo")
    }
}
