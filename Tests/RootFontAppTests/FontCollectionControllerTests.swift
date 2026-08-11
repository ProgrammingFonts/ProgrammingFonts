import XCTest
@testable import RootFontApp

final class FontCollectionControllerTests: XCTestCase {
    func testManualCollectionTrimsNameAndIncludesSelection() {
        let collection = FontCollectionController.manualCollection(named: "  Coding  ", selectedFontID: "Mono")
        XCTAssertEqual(collection?.name, "Coding")
        XCTAssertEqual(collection?.fontIDs, ["Mono"])
    }

    func testToggleTagRemovesEmptyAssignmentAndBuildsIndex() {
        var assignments = ["Mono": ["coding"]]
        FontCollectionController.toggleTag("coding", fontID: "Mono", assignments: &assignments)
        XCTAssertNil(assignments["Mono"])
        XCTAssertEqual(
            FontCollectionController.addTag(named: " terminal ", fontID: "Mono", assignments: &assignments),
            "terminal"
        )
        let index = FontCollectionController.tagIndex(assignments: assignments)
        XCTAssertEqual(index.fontIDsByTag["terminal"], ["Mono"])
        XCTAssertEqual(index.sortedNames, ["terminal"])
    }

    func testRejectsBlankNamesAndDuplicateTags() {
        XCTAssertNil(FontCollectionController.manualCollection(named: " \n ", selectedFontID: nil))
        XCTAssertNil(FontCollectionController.smartCollection(
            named: "\t", searchQuery: "", glyphCoverageQuery: "", selectedSource: nil,
            selectedStyle: nil, sidebarFilter: .all
        ))
        var assignments = ["Mono": ["terminal"]]
        XCTAssertNil(FontCollectionController.addTag(
            named: " terminal ", fontID: "Mono", assignments: &assignments
        ))
        XCTAssertEqual(assignments, ["Mono": ["terminal"]])
    }

    func testToggleFontReturnsFalseForUnknownCollection() {
        var collections = [ManualCollection(name: "Coding", fontIDs: [])]
        XCTAssertFalse(FontCollectionController.toggleFont(
            fontID: "Mono", collectionID: "missing", in: &collections
        ))
        XCTAssertTrue(collections[0].fontIDs.isEmpty)
    }
}
