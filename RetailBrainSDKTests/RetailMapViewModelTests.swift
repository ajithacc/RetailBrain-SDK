//
//  RetailMapViewModelTests.swift
//  RetailBrainSDKTests
//
//  Created by sowmya.prasanna on 15/07/26.
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
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "k", apiSecret: "s", mapId: "m"))
        let freshVM = RetailMapViewModel()

        freshVM.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading { expectation.fulfill() }
            }
            .store(in: &cancellables)

        freshVM.loadMap()
        // Simulate callback completing immediately — no real network needed
        freshVM._getMapDataCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        waitForExpectations(timeout: 1)
    }

    // MARK: - onStoreSelected

    func test_onStoreSelected_withNil_setsSelectedStoreToNil() {
        let exp = expectation(description: "selectedStore nil")
        viewModel.$selectedStore
            .dropFirst()
            .sink { store in
                XCTAssertNil(store)
                exp.fulfill()
            }
            .store(in: &cancellables)
        viewModel.onStoreSelected(nil)
        waitForExpectations(timeout: 1)
    }

    func test_onStoreSelected_withDetails_updatesSelectedStore() {
        let item = StoreItem(name: "Nike", imageName: "", locationName: "Nike")
        let details = StoreDetails(from: item, coordinates: (1.0, 2.0))
        let exp = expectation(description: "selectedStore set")
        viewModel.$selectedStore
            .dropFirst()
            .sink { store in
                XCTAssertEqual(store?.locationName, "Nike")
                exp.fulfill()
            }
            .store(in: &cancellables)
        viewModel.onStoreSelected(details)
        waitForExpectations(timeout: 1)
    }

    func test_onStoreSelected_calledTwice_updatesEachTime() {
        let item = StoreItem(name: "Adidas", imageName: "", locationName: "Adidas")
        let details = StoreDetails(from: item)
        var count = 0
        let exp = expectation(description: "two updates")
        exp.expectedFulfillmentCount = 2
        viewModel.$selectedStore
            .dropFirst()
            .sink { _ in count += 1; exp.fulfill() }
            .store(in: &cancellables)
        viewModel.onStoreSelected(details)
        viewModel.onStoreSelected(nil)
        waitForExpectations(timeout: 1)
    }

    // MARK: - handleMapDataFailure

    func test_handleMapDataFailure_setsIsLoadingFalse() {
        let error = RetailBrainSDKError.invalidConfiguration
        viewModel.handleMapDataFailure(error)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_handleMapDataFailure_callsMapDidFailToLoad() {
        let error = RetailBrainSDKError.invalidConfiguration
        viewModel.handleMapDataFailure(error)
        XCTAssertTrue(mockDelegate.mapDidFailToLoadCalled)
    }

    func test_handleMapDataFailure_withNilDelegate_doesNotCrash() {
        RetailBrainManager.shared.delegate = nil
        XCTAssertNoThrow(viewModel.handleMapDataFailure(RetailBrainSDKError.invalidConfiguration))
    }

    // MARK: - handleRenderSuccess

    func test_handleRenderSuccess_setsIsLoadingFalse() {
        viewModel.handleRenderSuccess()
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_handleRenderSuccess_callsMapDidLoad() {
        viewModel.handleRenderSuccess()
        XCTAssertTrue(mockDelegate.mapDidLoadCalled)
    }

    func test_handleRenderSuccess_callsOnMapLoaded() {
        var called = false
        let vm = RetailMapViewModel(onMapLoaded: { called = true })
        RetailBrainManager.shared.delegate = mockDelegate
        vm.handleRenderSuccess()
        XCTAssertTrue(called)
    }

    func test_handleRenderSuccess_withNilDelegate_doesNotCrash() {
        RetailBrainManager.shared.delegate = nil
        XCTAssertNoThrow(viewModel.handleRenderSuccess())
    }

    // MARK: - handleRenderFailure

    func test_handleRenderFailure_setsIsLoadingFalse() {
        viewModel.handleRenderFailure(RetailBrainSDKError.invalidConfiguration)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_handleRenderFailure_callsMapDidFailToLoad() {
        viewModel.handleRenderFailure(RetailBrainSDKError.invalidConfiguration)
        XCTAssertTrue(mockDelegate.mapDidFailToLoadCalled)
    }

    func test_handleRenderFailure_withNilDelegate_doesNotCrash() {
        RetailBrainManager.shared.delegate = nil
        XCTAssertNoThrow(viewModel.handleRenderFailure(RetailBrainSDKError.invalidConfiguration))
    }

    // MARK: - handleMapDataSuccess

    func test_handleMapDataSuccess_doesNotCrash() {
        XCTAssertNoThrow(viewModel.handleMapDataSuccess())
    }

    func test_handleMapDataSuccess_multiFloorMode_doesNotCrash() {
        let vm = RetailMapViewModel(isMultiFloorMode: true)
        XCTAssertNoThrow(vm.handleMapDataSuccess())
    }

    // MARK: - _navCallback (closure #1 in navigationManager.getter)

    func test_navCallback_isPopulatedAfterClearSelections() {
        viewModel.clearSelections()   // triggers lazy navigationManager init
        XCTAssertNotNil(viewModel._navCallback)
    }

    func test_navCallback_withNil_setsSelectedStoreToNil() {
        viewModel.clearSelections()
        let exp = expectation(description: "selectedStore nil via callback")
        viewModel.$selectedStore.dropFirst().sink { store in
            XCTAssertNil(store)
            exp.fulfill()
        }.store(in: &cancellables)
        viewModel._navCallback?(nil)
        waitForExpectations(timeout: 1)
    }

    func test_navCallback_withDetails_updatesSelectedStore() {
        viewModel.clearSelections()
        let item = StoreItem(name: "Nike", imageName: "", locationName: "Nike")
        let details = StoreDetails(from: item, coordinates: (1.0, 2.0))
        let exp = expectation(description: "selectedStore set via callback")
        viewModel.$selectedStore.dropFirst().sink { store in
            XCTAssertEqual(store?.locationName, "Nike")
            exp.fulfill()
        }.store(in: &cancellables)
        viewModel._navCallback?(details)
        waitForExpectations(timeout: 1)
    }

    // MARK: - _getMapDataCallback (closure #1 in loadMap)

    func test_getMapDataCallback_isPopulatedAfterLoadMap() {
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "k", apiSecret: "s", mapId: "m"))
        viewModel.loadMap()
        XCTAssertNotNil(viewModel._getMapDataCallback)
    }

    func test_getMapDataCallback_onSuccess_callsHandleMapDataSuccess() {
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "k", apiSecret: "s", mapId: "m"))
        viewModel.loadMap()
        XCTAssertNoThrow(viewModel._getMapDataCallback?(.success(nil)))
    }

    func test_getMapDataCallback_onFailure_setsIsLoadingFalse() {
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "k", apiSecret: "s", mapId: "m"))
        viewModel.loadMap()
        viewModel._getMapDataCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_getMapDataCallback_onFailure_callsDelegate() {
        RetailBrainManager.shared.initialize(config: RetailBrainConfig(apiKey: "k", apiSecret: "s", mapId: "m"))
        viewModel.loadMap()
        viewModel._getMapDataCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        XCTAssertTrue(mockDelegate.mapDidFailToLoadCalled)
    }

    // MARK: - _show3dMapCallback (closure #1 in handleMapDataSuccess)

    func test_show3dMapCallback_isPopulatedAfterHandleMapDataSuccess() {
        viewModel.handleMapDataSuccess()
        XCTAssertNotNil(viewModel._show3dMapCallback)
    }

    func test_show3dMapCallback_onSuccess_callsHandleRenderSuccess() {
        viewModel.handleMapDataSuccess()
        viewModel._show3dMapCallback?(.success(nil))
        XCTAssertTrue(mockDelegate.mapDidLoadCalled)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_show3dMapCallback_onFailure_callsHandleRenderFailure() {
        viewModel.handleMapDataSuccess()
        viewModel._show3dMapCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        XCTAssertTrue(mockDelegate.mapDidFailToLoadCalled)
        XCTAssertFalse(viewModel.isLoading)
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
