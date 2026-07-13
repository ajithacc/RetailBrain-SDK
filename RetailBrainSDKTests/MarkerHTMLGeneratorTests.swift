//
//  MarkerHTMLGeneratorTests.swift
//  RetailBrainSDKTests
//

import XCTest
@testable import RetailBrainSDK

final class MarkerHTMLGeneratorTests: XCTestCase {

    // MARK: - customDestinationMarkerHTML

    func test_customDestinationMarkerHTML_containsImageSrc() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "https://example.com/img.png", destinationId: "dest1")
        XCTAssertTrue(html.contains("https://example.com/img.png"))
    }

    func test_customDestinationMarkerHTML_containsDestinationId_inClipPath() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "img.png", destinationId: "store-42")
        XCTAssertTrue(html.contains("cp\("store-42")"))
    }

    func test_customDestinationMarkerHTML_defaultColor_isRed() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "img.png", destinationId: "d1")
        XCTAssertTrue(html.contains("#d92d20"))
    }

    func test_customDestinationMarkerHTML_customColor_isUsed() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "img.png", destinationId: "d1", color: "#00ff00")
        XCTAssertTrue(html.contains("#00ff00"))
        XCTAssertFalse(html.contains("#d92d20"))
    }

    func test_customDestinationMarkerHTML_containsValidSVG() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "img.png", destinationId: "d1")
        XCTAssertTrue(html.contains("<svg"))
        XCTAssertTrue(html.contains("</svg>"))
    }

    func test_customDestinationMarkerHTML_containsWrapperDiv() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "img.png", destinationId: "d1")
        XCTAssertTrue(html.contains("<div"))
        XCTAssertTrue(html.contains("</div>"))
    }

    func test_customDestinationMarkerHTML_emptyImageSrc_producesValidHTML() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "", destinationId: "d1")
        XCTAssertTrue(html.contains("<svg"))
    }

    func test_customDestinationMarkerHTML_specialCharactersInDestinationId_areIncluded() {
        let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "img.png", destinationId: "id-123_test")
        XCTAssertTrue(html.contains("cpid-123_test"))
    }

    // MARK: - startMarkerHTML

    func test_startMarkerHTML_containsTitle() {
        let html = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000000")
        XCTAssertTrue(html.contains(">A<"))
    }

    func test_startMarkerHTML_withSubtitle_containsSubtitle() {
        let html = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: "Entrance", color: "#000000")
        XCTAssertTrue(html.contains("Entrance"))
    }

    func test_startMarkerHTML_withNilSubtitle_doesNotContainBareSpan() {
        let html = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000000")
        // The title badge uses <span style="...">; only the subtitle uses a bare <span>.
        // When subtitle is nil, there should be no bare <span> in the output.
        let bareSpanCount = html.components(separatedBy: "<span>").count - 1
        XCTAssertEqual(bareSpanCount, 0)
    }

    func test_startMarkerHTML_containsColor() {
        let html = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#ff0000")
        XCTAssertTrue(html.contains("#ff0000"))
    }

    func test_startMarkerHTML_compact_usesSmallerFontSize() {
        let compactHTML = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000", compact: true)
        let normalHTML = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000", compact: false)
        XCTAssertTrue(compactHTML.contains("11px"))
        XCTAssertTrue(normalHTML.contains("12px"))
    }

    func test_startMarkerHTML_compact_usesSmallerBadgeSize() {
        let compactHTML = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000", compact: true)
        let normalHTML = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000", compact: false)
        XCTAssertTrue(compactHTML.contains("18px"))
        XCTAssertTrue(normalHTML.contains("20px"))
    }

    func test_startMarkerHTML_compact_usesSmallerBorderRadius() {
        let compactHTML = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000", compact: true)
        let normalHTML = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000", compact: false)
        XCTAssertTrue(compactHTML.contains("12px"))
        XCTAssertTrue(normalHTML.contains("14px"))
    }

    func test_startMarkerHTML_defaultIsNotCompact() {
        let html = MarkerHTMLGenerator.startMarkerHTML(title: "S", subtitle: nil, color: "#000")
        XCTAssertTrue(html.contains("12px")) // normal font size
    }

    func test_startMarkerHTML_containsWhiteBackground() {
        let html = MarkerHTMLGenerator.startMarkerHTML(title: "A", subtitle: nil, color: "#000000")
        XCTAssertTrue(html.contains("background: white"))
    }

    func test_startMarkerHTML_isNonEmpty() {
        let html = MarkerHTMLGenerator.startMarkerHTML(title: "", subtitle: nil, color: "")
        XCTAssertFalse(html.isEmpty)
    }
}
