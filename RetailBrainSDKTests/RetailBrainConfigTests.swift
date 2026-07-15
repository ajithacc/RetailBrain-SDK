//
//  RetailBrainConfigTests.swift
//  RetailBrainSDKTests
//
//  Created by sowmya.prasanna on 15/07/26.
//

import XCTest
@testable import RetailBrainSDK

final class RetailBrainConfigTests: XCTestCase {

    func test_init_storesApiKey() {
        let config = RetailBrainConfig(apiKey: "myKey", apiSecret: "mySecret", mapId: "myMap")
        XCTAssertEqual(config.apiKey, "myKey")
    }

    func test_init_storesApiSecret() {
        let config = RetailBrainConfig(apiKey: "myKey", apiSecret: "mySecret", mapId: "myMap")
        XCTAssertEqual(config.apiSecret, "mySecret")
    }

    func test_init_storesMapId() {
        let config = RetailBrainConfig(apiKey: "myKey", apiSecret: "mySecret", mapId: "myMap")
        XCTAssertEqual(config.mapId, "myMap")
    }

    func test_init_withEmptyStrings_preservesEmptyValues() {
        let config = RetailBrainConfig(apiKey: "", apiSecret: "", mapId: "")
        XCTAssertTrue(config.apiKey.isEmpty)
        XCTAssertTrue(config.apiSecret.isEmpty)
        XCTAssertTrue(config.mapId.isEmpty)
    }

    func test_init_withWhitespaceOnlyValues_preservesWhitespace() {
        let config = RetailBrainConfig(apiKey: " ", apiSecret: "\t", mapId: "\n")
        XCTAssertEqual(config.apiKey, " ")
        XCTAssertEqual(config.apiSecret, "\t")
        XCTAssertEqual(config.mapId, "\n")
    }

    func test_init_withSpecialCharacters_preservesValues() {
        let config = RetailBrainConfig(apiKey: "key!@#$%", apiSecret: "secret&*()", mapId: "map-id_v2")
        XCTAssertEqual(config.apiKey, "key!@#$%")
        XCTAssertEqual(config.apiSecret, "secret&*()")
        XCTAssertEqual(config.mapId, "map-id_v2")
    }
}
