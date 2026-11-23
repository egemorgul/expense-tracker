import SwiftData
import XCTest
@testable import ExpenseTracker

/// The phone's data is in the App Group container, where SwiftData's default put it. If the app ever
/// looked elsewhere, it would open an old copy of the store, see CLAUDE.md.
final class StoreLocationTests: XCTestCase {
    func testLiveStoreIsInTheAppGroup() throws {
        let group = try XCTUnwrap(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup))

        XCTAssertEqual(
            ModelConfiguration.liveStore.url.standardizedFileURL.path,
            group.appending(path: "Library/Application Support/default.store").standardizedFileURL.path
        )
    }

    func testLiveStoreIsWhereTheDefaultAlreadyPutIt() {
        XCTAssertEqual(ModelConfiguration.liveStore.url.standardizedFileURL.path, ModelConfiguration().url.standardizedFileURL.path)
    }
}
