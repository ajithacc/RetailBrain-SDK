//
//  RetailBrainSDKDelegateDefaultsTests.swift
//  RetailBrainSDKTests
//
//  Created by sowmya.prasanna on 15/07/26.
//
//  Verifies that protocol default implementations do not crash when called.
//

import XCTest
@testable import RetailBrainSDK

final class RetailBrainSDKDelegateDefaultsTests: XCTestCase {

    private var sut: DefaultOnlyDelegate!

    override func setUp() {
        super.setUp()
        sut = DefaultOnlyDelegate()
    }

    func test_defaultSdkDidInitialize_doesNotCrash() {
        XCTAssertNoThrow(sut.sdkDidInitialize())
    }

    func test_defaultSdkDidFailToInitialize_doesNotCrash() {
        let error = RetailBrainSDKError.invalidConfiguration
        XCTAssertNoThrow(sut.sdkDidFailToInitialize(error: error))
    }

    func test_defaultMapDidLoad_doesNotCrash() {
        XCTAssertNoThrow(sut.mapDidLoad())
    }

    func test_defaultMapDidFailToLoad_doesNotCrash() {
        let error = RetailBrainSDKError.invalidConfiguration
        XCTAssertNoThrow(sut.mapDidFailToLoad(error: error))
    }

    func test_defaultAddProductToMap_doesNotCrash() {
        XCTAssertNoThrow(sut.addProductToMap())
    }

    func test_defaultDidSelectItem_doesNotCrash() {
        let item = StoreItem(name: "Nike", imageName: "img.png", locationName: "A1")
        XCTAssertNoThrow(sut.didSelectItem(item))
    }

    func test_defaultDidDeselectItem_doesNotCrash() {
        let item = StoreItem(name: "Nike", imageName: "img.png", locationName: "A1")
        XCTAssertNoThrow(sut.didDeselectItem(item))
    }

    func test_defaultRouteCalculationStarted_doesNotCrash() {
        XCTAssertNoThrow(sut.routeCalculationStarted())
    }
}

// Uses only default protocol implementations — nothing is overridden.
private final class DefaultOnlyDelegate: RetailBrainSDKDelegate {}
