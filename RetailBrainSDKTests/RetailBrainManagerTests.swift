//
//  RetailBrainManagerTests.swift
//  RetailBrainSDKTests
//
//  Created by sowmya.prasanna on 15/07/26.
//

import XCTest
@testable import RetailBrainSDK

final class RetailBrainManagerTests: XCTestCase {

    private var manager: RetailBrainManager!
    private var mockDelegate: MockRetailBrainSDKDelegate!

    override func setUp() {
        super.setUp()
        manager = RetailBrainManager.shared
        mockDelegate = MockRetailBrainSDKDelegate()
        manager.delegate = mockDelegate
    }

    override func tearDown() {
        manager.delegate = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Singleton

    func test_shared_returnsSameInstance() {
        let first = RetailBrainManager.shared
        let second = RetailBrainManager.shared
        XCTAssertTrue(first === second)
    }

    // MARK: - Valid Configuration

    func test_initialize_withValidConfig_setsConfig() {
        let config = RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "map1")
        manager.initialize(config: config)
        XCTAssertNotNil(manager.config)
        XCTAssertEqual(manager.config?.apiKey, "key")
        XCTAssertEqual(manager.config?.apiSecret, "secret")
        XCTAssertEqual(manager.config?.mapId, "map1")
    }

    func test_initialize_withValidConfig_callsDelegateDidInitialize() {
        let config = RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "map1")
        manager.initialize(config: config)
        XCTAssertTrue(mockDelegate.didInitializeCalled)
    }

    func test_initialize_withValidConfig_doesNotCallFailure() {
        let config = RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "map1")
        manager.initialize(config: config)
        XCTAssertFalse(mockDelegate.didFailToInitializeCalled)
    }

    // MARK: - Invalid Configuration

    func test_initialize_withEmptyApiKey_callsDelegateFailure() {
        let config = RetailBrainConfig(apiKey: "", apiSecret: "secret", mapId: "map1")
        manager.initialize(config: config)
        XCTAssertTrue(mockDelegate.didFailToInitializeCalled)
    }

    func test_initialize_withEmptyApiSecret_callsDelegateFailure() {
        let config = RetailBrainConfig(apiKey: "key", apiSecret: "", mapId: "map1")
        manager.initialize(config: config)
        XCTAssertTrue(mockDelegate.didFailToInitializeCalled)
    }

    func test_initialize_withEmptyMapId_callsDelegateFailure() {
        let config = RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "")
        manager.initialize(config: config)
        XCTAssertTrue(mockDelegate.didFailToInitializeCalled)
    }

    func test_initialize_withAllEmptyFields_callsDelegateFailure() {
        let config = RetailBrainConfig(apiKey: "", apiSecret: "", mapId: "")
        manager.initialize(config: config)
        XCTAssertTrue(mockDelegate.didFailToInitializeCalled)
    }

    func test_initialize_withInvalidConfig_doesNotSetConfig() {
        // Clear config first via valid init, then override with invalid
        let invalidConfig = RetailBrainConfig(apiKey: "", apiSecret: "secret", mapId: "map1")
        let previousConfig = manager.config
        manager.initialize(config: invalidConfig)
        // Config should remain unchanged (not set to invalid)
        XCTAssertEqual(manager.config?.apiKey, previousConfig?.apiKey)
    }

    func test_initialize_withInvalidConfig_failureErrorIsInvalidConfiguration() {
        let config = RetailBrainConfig(apiKey: "", apiSecret: "secret", mapId: "map1")
        manager.initialize(config: config)
        guard let error = mockDelegate.receivedError as? RetailBrainSDKError else {
            return XCTFail("Expected RetailBrainSDKError")
        }
        XCTAssertEqual(error, .invalidConfiguration)
    }

    // MARK: - No Delegate

    func test_initialize_withNilDelegate_doesNotCrash() {
        manager.delegate = nil
        let config = RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "map1")
        XCTAssertNoThrow(manager.initialize(config: config))
    }

    func test_initialize_withNilDelegateAndInvalidConfig_doesNotCrash() {
        manager.delegate = nil
        let config = RetailBrainConfig(apiKey: "", apiSecret: "secret", mapId: "map1")
        XCTAssertNoThrow(manager.initialize(config: config))
    }
}

// MARK: - Mock Delegate

final class MockRetailBrainSDKDelegate: RetailBrainSDKDelegate {
    var didInitializeCalled = false
    var didFailToInitializeCalled = false
    var receivedError: Error?
    var mapDidLoadCalled = false
    var mapDidFailToLoadCalled = false
    var addProductToMapCalled = false
    var selectedItem: StoreItem?
    var deselectedItem: StoreItem?
    var routeCalculationStartedCalled = false

    func sdkDidInitialize() { didInitializeCalled = true }
    func sdkDidFailToInitialize(error: Error) {
        didFailToInitializeCalled = true
        receivedError = error
    }
    func mapDidLoad() { mapDidLoadCalled = true }
    func mapDidFailToLoad(error: Error) { mapDidFailToLoadCalled = true }
    func addProductToMap() { addProductToMapCalled = true }
    func didSelectItem(_ item: StoreItem) { selectedItem = item }
    func didDeselectItem(_ item: StoreItem) { deselectedItem = item }
    func routeCalculationStarted() { routeCalculationStartedCalled = true }
}
