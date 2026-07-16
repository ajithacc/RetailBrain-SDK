import XCTest
@testable import RetailBrainSDK

final class MarkerHTMLGeneratorTests: XCTestCase {

    func testCustomDestinationMarkerHTML_EmbedsGivenValues() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(
            imageSrc: "https://example.com/product.png",
            destinationId: "destination-123",
            color: "#ff00aa"
        )

        XCTAssertTrue(html.contains("https://example.com/product.png"))
        XCTAssertTrue(html.contains("cpdestination-123"))
        XCTAssertTrue(html.contains("fill=\"#ff00aa\""))
        XCTAssertTrue(html.contains("stroke=\"#ff00aa\""))
    }

    func testCustomDestinationMarkerHTML_UsesDefaultColorWhenNotProvided() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(
            imageSrc: "image.png",
            destinationId: "d1"
        )

        XCTAssertTrue(html.contains("fill=\"#000000\""))
    }

    func testStartMarkerHTML_CompactModeUsesCompactSizing() {
        let html = MarkerHTMLGenerator.startMarkerHTML(
            title: "A",
            subtitle: "Start",
            color: "#123456",
            compact: true
        )

        XCTAssertTrue(html.contains("gap: 4px"))
        XCTAssertTrue(html.contains("font-size: 11px"))
        XCTAssertTrue(html.contains("height: 18px"))
        XCTAssertTrue(html.contains("min-width: 18px"))
        XCTAssertTrue(html.contains("<span>Start</span>"))
    }

    func testStartMarkerHTML_NonCompactModeUsesDefaultSizing() {
        let html = MarkerHTMLGenerator.startMarkerHTML(
            title: "B",
            subtitle: nil,
            color: "#abcdef",
            compact: false
        )

        XCTAssertTrue(html.contains("gap: 6px"))
        XCTAssertTrue(html.contains("font-size: 12px"))
        XCTAssertTrue(html.contains("height: 20px"))
        XCTAssertFalse(html.contains("<span></span>"))
    }
}
