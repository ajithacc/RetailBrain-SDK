//
//  RetailMapViewModelTests.swift
//  RetailBrainSDKTests
//

import XCTest
import Combine
import SwiftUI
import UIKit
import Mappedin
@testable import RetailBrainSDK

final class RetailMapViewModelTests: XCTestCase {

    private var viewModel: RetailMapViewModel!
    private var mockDelegate: MockRetailBrainSDKDelegate!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        
        super.setUp()
        mockDelegate = MockRetailBrainSDKDelegate()
        RetailBrainManager.shared.delegate = mockDelegate
        viewModel = RetailMapViewModel()
    }

    override func tearDown() {
        cancellables.removeAll()
        RetailBrainManager.shared.delegate = nil
        viewModel = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Init

    func test_init_isLoadingIsTrue() {
        XCTAssertTrue(viewModel.isLoading)
    }

    func test_init_selectedStoreIsNil() {
        XCTAssertNil(viewModel.selectedStore)
    }

    func test_init_withCustomOnMapLoaded_doesNotCrash() {
        var called = false
        let vm = RetailMapViewModel(onMapLoaded: { called = true })
        XCTAssertNotNil(vm)
        XCTAssertFalse(called)
    }

    func test_init_withCustomMapId_doesNotCrash() {
        let vm = RetailMapViewModel(mapId: "custom-map-id")
        XCTAssertNotNil(vm)
    }

    func test_init_withMultiFloorMode_doesNotCrash() {
        let vm = RetailMapViewModel(isMultiFloorMode: true)
        XCTAssertNotNil(vm)
    }

    // MARK: - loadMap

    func test_loadMap_withNoConfig_setsIsLoadingFalse() throws {
        guard RetailBrainManager.shared.config == nil else {
            throw XCTSkip("RetailBrainManager.shared.config already initialized in this run; skipping no-config-only assertion")
        }

        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "", apiSecret: "", mapId: ""))
        let freshVM = RetailMapViewModel()
        freshVM.loadMap()
        XCTAssertFalse(freshVM.isLoading)
    }

    func test_loadMap_withNoConfig_callsMapDidFailToLoad() throws {
        guard RetailBrainManager.shared.config == nil else {
            throw XCTSkip("RetailBrainManager.shared.config already initialized in this run; skipping no-config-only assertion")
        }

        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "", apiSecret: "", mapId: ""))
        let freshVM = RetailMapViewModel()
        freshVM.loadMap()
        XCTAssertTrue(mockDelegate.mapDidFailToLoadCalled)
    }

    func test_loadMap_withNoConfig_doesNotCallMapDidLoad() throws {
        guard RetailBrainManager.shared.config == nil else {
            throw XCTSkip("RetailBrainManager.shared.config already initialized in this run; skipping no-config-only assertion")
        }

        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "", apiSecret: "", mapId: ""))
        let freshVM = RetailMapViewModel()
        freshVM.loadMap()
        XCTAssertFalse(mockDelegate.mapDidLoadCalled)
    }

    func test_loadMap_withValidConfig_doesNotCrash() {
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "map-id"))
        let freshVM = RetailMapViewModel()
        XCTAssertNoThrow(freshVM.loadMap())
    }

    func test_loadMap_withValidConfigAndCustomMapId_doesNotCrash() {
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "config-map"))
        let freshVM = RetailMapViewModel(mapId: "custom-map-id")
        XCTAssertNoThrow(freshVM.loadMap())
    }

    func test_loadMap_withNilDelegateAndValidConfig_doesNotCrash() {
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "map-id"))
        RetailBrainManager.shared.delegate = nil
        let freshVM = RetailMapViewModel()
        XCTAssertNoThrow(freshVM.loadMap())
    }

    // MARK: - routeToItems

    func test_routeToItems_withEmptyArray_doesNotCallDelegate() {
        viewModel.routeToItems([])
        XCTAssertFalse(mockDelegate.routeCalculationStartedCalled)
    }

    func test_routeToItems_withItems_callsRouteCalculationStarted() {
        viewModel.routeToItems(["Nike"])
        XCTAssertTrue(mockDelegate.routeCalculationStartedCalled)
    }

    func test_routeToItems_withMultipleItems_callsRouteCalculationStarted() {
        viewModel.routeToItems(["Nike", "Adidas", "Puma"])
        XCTAssertTrue(mockDelegate.routeCalculationStartedCalled)
    }

    func test_routeToItems_withNilDelegate_doesNotCrash() {
        RetailBrainManager.shared.delegate = nil
        XCTAssertNoThrow(viewModel.routeToItems(["Nike"]))
    }

    // MARK: - clearSelections

    func test_clearSelections_doesNotCrash() {
        XCTAssertNoThrow(viewModel.clearSelections())
    }

    func test_clearSelections_afterRouteToItems_doesNotCrash() {
        viewModel.routeToItems(["Nike"])
        XCTAssertNoThrow(viewModel.clearSelections())
    }

    // MARK: - isLoading published changes

    func test_isLoading_initiallyTrue() {
        let vm = RetailMapViewModel()
        XCTAssertTrue(vm.isLoading)
    }

    func test_isLoading_publishesChanges() {
        let expectation = expectation(description: "isLoading published false")
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "", apiSecret: "", mapId: ""))
        let freshVM = RetailMapViewModel()

        freshVM.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading { expectation.fulfill() }
            }
            .store(in: &cancellables)

        freshVM.loadMap()
        waitForExpectations(timeout: 1)
    }
}

@MainActor
final class RetailMapViewTests: XCTestCase {

    private var mockDelegate: MockRetailBrainSDKDelegate!

    override func setUp() {
        super.setUp()
        mockDelegate = MockRetailBrainSDKDelegate()
        RetailBrainManager.shared.delegate = mockDelegate
    }

    override func tearDown() {
        RetailBrainManager.shared.delegate = nil
        mockDelegate = nil
        super.tearDown()
    }

    func test_mapViewContainer_init_setsClearBackground() {
        let mapView = MapView()
        defer { mapView.destroy() }
        let container = MapViewContainer(mapView: mapView)
        XCTAssertEqual(container.backgroundColor, UIColor.clear)
    }

    func test_mapViewRepresentable_rendersMapViewContainer() {
        let mapView = MapView()
        defer { mapView.destroy() }
        let host = UIHostingController(rootView: MapViewRepresentable(mapView: mapView))
        XCTAssertNoThrow(host.loadViewIfNeeded())
    }

    func test_mapViewRepresentable_rootViewUpdate_doesNotCrash() {
        let mapView = MapView()
        defer { mapView.destroy() }
        let updatedMapView = MapView()
        defer { updatedMapView.destroy() }
        let host = UIHostingController(rootView: MapViewRepresentable(mapView: mapView))
        host.loadViewIfNeeded()

        XCTAssertNoThrow({
            host.rootView = MapViewRepresentable(mapView: updatedMapView)
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }())
    }

    func test_mapViewRepresentable_multipleRootUpdates_keepContainerPresent() {
        let firstMapView = MapView()
        defer { firstMapView.destroy() }
        let secondMapView = MapView()
        defer { secondMapView.destroy() }
        let thirdMapView = MapView()
        defer { thirdMapView.destroy() }
        let host = UIHostingController(rootView: MapViewRepresentable(mapView: firstMapView))
        host.loadViewIfNeeded()

        XCTAssertNoThrow({
            host.rootView = MapViewRepresentable(mapView: secondMapView)
            host.rootView = MapViewRepresentable(mapView: thirdMapView)
            host.view.layoutIfNeeded()
        }())
    }

    func test_retailMapView_init_withDefaults_doesNotCrash() {
        let view = RetailMapView()
        XCTAssertNotNil(view)
    }

    func test_retailMapView_init_withCustomParameters_doesNotCrash() {
        let routingController = MapRoutingController()
        var mapLoadedCalled = false
        var launchCalled = false

        let view = RetailMapView(
            routingController: routingController,
            onMapLoaded: { mapLoadedCalled = true },
            onLaunch: { launchCalled = true },
            mapId: "custom-map-id",
            isMultiFloorMode: true
        )

        XCTAssertNotNil(view)
        XCTAssertFalse(mapLoadedCalled)
        XCTAssertFalse(launchCalled)
    }

    func test_retailMapView_hostedLifecycle_doesNotCrash() {
        let host = UIHostingController(rootView: RetailMapView(routingController: MapRoutingController()))

        XCTAssertNoThrow({
            host.loadViewIfNeeded()
            host.beginAppearanceTransition(true, animated: false)
            host.endAppearanceTransition()
            host.beginAppearanceTransition(false, animated: false)
            host.endAppearanceTransition()
        }())
    }
}
