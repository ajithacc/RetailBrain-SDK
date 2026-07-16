import XCTest
@testable import RetailBrainSDK

final class RetailBrainManagerTests: XCTestCase {

    private final class MockDelegate: RetailBrainSDKDelegate {
        var didInitialize = false
        var didFailToInitialize = false
        var initializationError: Error?

        func sdkDidInitialize() {
            didInitialize = true
        }

        func sdkDidFailToInitialize(error: Error) {
            didFailToInitialize = true
            initializationError = error
        }
    }

    func testInitializeWithValidConfig_NotifiesDelegateAndStoresConfig() {
        let sut = RetailBrainManager.shared
        let delegate = MockDelegate()
        sut.delegate = delegate

        let config = RetailBrainConfig(
            apiKey: "test-key",
            apiSecret: "test-secret",
            mapId: "test-map"
        )

        sut.initialize(config: config)

        XCTAssertTrue(delegate.didInitialize)
        XCTAssertFalse(delegate.didFailToInitialize)
        XCTAssertEqual(sut.config?.apiKey, "test-key")
        XCTAssertEqual(sut.config?.apiSecret, "test-secret")
        XCTAssertEqual(sut.config?.mapId, "test-map")
    }

    func testInitializeWithInvalidConfig_NotifiesFailureAndDoesNotCallSuccess() {
        let sut = RetailBrainManager.shared
        let delegate = MockDelegate()
        sut.delegate = delegate

        let previousConfig = sut.config
        let invalidConfig = RetailBrainConfig(apiKey: "", apiSecret: "", mapId: "")

        sut.initialize(config: invalidConfig)

        XCTAssertFalse(delegate.didInitialize)
        XCTAssertTrue(delegate.didFailToInitialize)

        guard let error = delegate.initializationError as? RetailBrainSDKError else {
            return XCTFail("Expected RetailBrainSDKError.invalidConfiguration")
        }

        switch error {
        case .invalidConfiguration:
            break
        }
        XCTAssertEqual(sut.config?.mapId, previousConfig?.mapId)
    }

    func testInvalidConfigurationErrorDescription_IsUserFriendly() {
        XCTAssertEqual(
            RetailBrainSDKError.invalidConfiguration.errorDescription,
            "RetailBrain configuration is invalid."
        )
    }
}
