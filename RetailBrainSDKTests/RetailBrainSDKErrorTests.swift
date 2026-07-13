//
//  RetailBrainSDKErrorTests.swift
//  RetailBrainSDKTests
//

import XCTest
@testable import RetailBrainSDK

final class RetailBrainSDKErrorTests: XCTestCase {

    func test_invalidConfiguration_errorDescription_isNotNil() {
        let error = RetailBrainSDKError.invalidConfiguration
        XCTAssertNotNil(error.errorDescription)
    }

    func test_invalidConfiguration_errorDescription_containsExpectedMessage() {
        let error = RetailBrainSDKError.invalidConfiguration
        XCTAssertEqual(error.errorDescription, "RetailBrain configuration is invalid.")
    }

    func test_invalidConfiguration_localizedDescription_isNonEmpty() {
        let error = RetailBrainSDKError.invalidConfiguration
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func test_invalidConfiguration_conformsToError() {
        let error: Error = RetailBrainSDKError.invalidConfiguration
        XCTAssertNotNil(error)
    }
}
