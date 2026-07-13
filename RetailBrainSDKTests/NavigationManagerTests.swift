//
//  NavigationManagerTests.swift
//  RetailBrainSDKTests
//

import XCTest
import Mappedin
@testable import RetailBrainSDK

final class NavigationManagerTests: XCTestCase {

    private var mapView: MapView!
    private var manager: NavigationManager!
    private var receivedStoreDetails: StoreDetails??
    private var callbackCallCount = 0

    override func setUp() {
        super.setUp()
        mapView = MapView()
        manager = NavigationManager(mapView: mapView) { [weak self] details in
            self?.receivedStoreDetails = details
            self?.callbackCallCount += 1
        }
    }

    override func tearDown() {
        mapView?.destroy()
        manager = nil
        mapView = nil
        super.tearDown()
    }

    // MARK: - Init

    func test_init_doesNotCrash() {
        XCTAssertNotNil(manager)
    }

    func test_init_withDifferentCallbacks_doesNotCrash() {
        let m1 = NavigationManager(mapView: MapView()) { _ in }
        let m2 = NavigationManager(mapView: MapView()) { details in _ = details }
        XCTAssertNotNil(m1)
        XCTAssertNotNil(m2)
    }

    // MARK: - prepareToDrawRoute

    func test_prepareToDrawRoute_withEmptyDestinations_doesNotCrash() {
        XCTAssertNoThrow(manager.prepareToDrawRoute(destinationNames: []))
    }

    func test_prepareToDrawRoute_withEmptyDestinations_isNoOp() {
        manager.prepareToDrawRoute(destinationNames: [])
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_prepareToDrawRoute_withSingleDestination_doesNotCrash() {
        XCTAssertNoThrow(manager.prepareToDrawRoute(destinationNames: ["Nike"]))
    }

    func test_prepareToDrawRoute_withMultipleDestinations_doesNotCrash() {
        XCTAssertNoThrow(manager.prepareToDrawRoute(destinationNames: ["Nike", "Adidas", "Puma"]))
    }

    func test_prepareToDrawRoute_calledMultipleTimes_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.prepareToDrawRoute(destinationNames: ["Adidas"])
        manager.prepareToDrawRoute(destinationNames: ["Puma", "Reebok"])
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_prepareToDrawRoute_withSpecialCharacterNames_doesNotCrash() {
        XCTAssertNoThrow(manager.prepareToDrawRoute(destinationNames: ["Store|Alias", "Store 2", "Cafe"]))
    }

    func test_prepareToDrawRoute_withWhitespaceNames_doesNotCrash() {
        XCTAssertNoThrow(manager.prepareToDrawRoute(destinationNames: [" Nike ", "\tAdidas\n"]))
    }

    func test_prepareToDrawRoute_setsExpectedPublicBehavior() {
        manager.prepareToDrawRoute(destinationNames: ["Nike", "Adidas"])
        XCTAssertEqual(callbackCallCount, 0)
        XCTAssertTrue(receivedStoreDetails == nil)
    }

    // MARK: - clearRoutes

    func test_clearRoutes_doesNotCrash() {
        XCTAssertNoThrow(manager.clearRoutes())
    }

    func test_clearRoutes_calledMultipleTimes_doesNotCrash() {
        manager.clearRoutes()
        manager.clearRoutes()
        manager.clearRoutes()
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_clearRoutes_afterPrepareToDrawRoute_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertNoThrow(manager.clearRoutes())
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_clearRoutes_beforePrepareToDrawRoute_doesNotCrash() {
        manager.clearRoutes()
        XCTAssertNoThrow(manager.prepareToDrawRoute(destinationNames: ["Nike"]))
    }

    // MARK: - Interleaved calls

    func test_prepareAndClear_alternating_doesNotCrash() {
        for i in 1...5 {
            manager.prepareToDrawRoute(destinationNames: ["Store\(i)"])
            manager.clearRoutes()
        }
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_clearAfterMultiplePrepares_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["A"])
        manager.prepareToDrawRoute(destinationNames: ["B"])
        manager.prepareToDrawRoute(destinationNames: ["C"])
        XCTAssertNoThrow(manager.clearRoutes())
    }

    // MARK: - Callback not invoked for public API calls

    func test_storeSelectCallback_notCalledOnPrepare() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_storeSelectCallback_notCalledOnClear() {
        manager.clearRoutes()
        XCTAssertEqual(callbackCallCount, 0)
    }

}
