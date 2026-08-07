import XCTest
@testable import RootFontApp

final class FontSelectionControllerTests: XCTestCase {
    func testCommandTapTogglesAndPlainTapReplacesSelection() {
        XCTAssertEqual(
            FontSelectionController.selectionAfterTap(
                fontID: "b",
                commandKey: true,
                current: ["a"]
            ),
            ["a", "b"]
        )
        XCTAssertEqual(
            FontSelectionController.selectionAfterTap(
                fontID: "a",
                commandKey: false,
                current: ["a", "b"]
            ),
            ["a"]
        )
    }

    func testBatchFavoriteAddsAllThenRemovesAll() {
        let selected: Set<String> = ["a", "b"]
        let added = FontSelectionController.toggledFavorites(
            selectedIDs: selected,
            favorites: ["a"]
        )
        XCTAssertEqual(added, selected)
        XCTAssertTrue(
            FontSelectionController.toggledFavorites(
                selectedIDs: selected,
                favorites: added
            ).isEmpty
        )
    }

    func testRecentsDeduplicatesAndHonorsLimit() {
        XCTAssertEqual(
            FontSelectionController.recents(
                adding: "b",
                to: ["a", "b", "c"],
                limit: 2
            ),
            ["b", "a"]
        )
    }

    func testAdjacentSelectionClampsAndRecoversFromMissingSelection() {
        let fonts = [
            FontItem.sample(id: "a", familyName: "A", source: .user, styleTags: []),
            FontItem.sample(id: "b", familyName: "B", source: .user, styleTags: [])
        ]
        XCTAssertEqual(
            FontSelectionController.adjacentFont(to: "a", offset: 5, in: fonts)?.id,
            "b"
        )
        XCTAssertEqual(
            FontSelectionController.adjacentFont(to: "missing", offset: 1, in: fonts)?.id,
            "a"
        )
    }
}
