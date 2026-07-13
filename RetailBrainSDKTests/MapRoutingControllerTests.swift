//
//  MapRoutingControllerTests.swift
//  RetailBrainSDKTests
//

import XCTest
import Combine
@testable import RetailBrainSDK

final class MapRoutingControllerTests: XCTestCase {

    private var controller: MapRoutingController!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        controller = MapRoutingController()
    }

    override func tearDown() {
        cancellables.removeAll()
        controller = nil
        super.tearDown()
    }

    // MARK: - Init

    func test_init_isMapReadyIsFalse() {
        XCTAssertFalse(controller.isMapReady)
    }

    // MARK: - markMapReady

    func test_markMapReady_setsIsMapReadyTrue() {
        controller.markMapReady()
        XCTAssertTrue(controller.isMapReady)
    }

    func test_markMapReady_publishesChange() {
        let expectation = expectation(description: "isMapReady published")
        controller.$isMapReady
            .dropFirst()
            .sink { isReady in
                if isReady { expectation.fulfill() }
            }
            .store(in: &cancellables)

        controller.markMapReady()
        waitForExpectations(timeout: 1)
    }

    func test_markMapReady_calledTwice_remainsTrue() {
        controller.markMapReady()
        controller.markMapReady()
        XCTAssertTrue(controller.isMapReady)
    }

    // MARK: - routeToStores (no attached viewModel)

    func test_routeToStores_withNoViewModel_doesNotCrash() {
        XCTAssertNoThrow(controller.routeToStores(["Nike", "Adidas"]))
    }

    func test_routeToStores_withEmptyArray_doesNotCrash() {
        XCTAssertNoThrow(controller.routeToStores([]))
    }

    func test_routeToStores_withSingleStore_doesNotCrash() {
        XCTAssertNoThrow(controller.routeToStores(["Nike"]))
    }

    // MARK: - clearRoute (no attached viewModel)

    func test_clearRoute_withNoViewModel_doesNotCrash() {
        XCTAssertNoThrow(controller.clearRoute())
    }

    func test_clearRoute_afterMarkMapReady_doesNotCrash() {
        controller.markMapReady()
        XCTAssertNoThrow(controller.clearRoute())
    }

    // MARK: - attach + routeToStores / clearRoute

    func test_attach_thenRouteToStores_doesNotCrash() {
        let viewModel = RetailMapViewModel()
        controller.attach(viewModel: viewModel)
        XCTAssertNoThrow(controller.routeToStores([]))
    }

    func test_attach_thenClearRoute_doesNotCrash() {
        let viewModel = RetailMapViewModel()
        controller.attach(viewModel: viewModel)
        XCTAssertNoThrow(controller.clearRoute())
    }
}
