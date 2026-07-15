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

    func test_storeSelectCallback_notCalledOnPrepare() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_storeSelectCallback_notCalledOnClear() {
        manager.clearRoutes()
        XCTAssertEqual(callbackCallCount, 0)
    }

    // MARK: - normalizedRouteName

    func test_normalizedRouteName_lowercasesAndTrims() {
        XCTAssertEqual(manager.normalizedRouteName("  Nike  "), "nike")
    }

    func test_normalizedRouteName_emptyString() {
        XCTAssertEqual(manager.normalizedRouteName(""), "")
    }

    func test_normalizedRouteName_mixedCase() {
        XCTAssertEqual(manager.normalizedRouteName("ADIDAS Store"), "adidas store")
    }

    func test_normalizedRouteName_tabsAndNewlines() {
        XCTAssertEqual(manager.normalizedRouteName("\tPuma\n"), "puma")
    }

    // MARK: - calculateBearing

    func test_calculateBearing_dueNorth_doesNotCrash() {
        let bearing = manager.calculateBearing(from: Coordinate(latitude: 0, longitude: 0), to: Coordinate(latitude: 1, longitude: 0))
        XCTAssertFalse(bearing.isNaN)
    }

    func test_calculateBearing_dueEast_doesNotCrash() {
        let bearing = manager.calculateBearing(from: Coordinate(latitude: 0, longitude: 0), to: Coordinate(latitude: 0, longitude: 1))
        XCTAssertFalse(bearing.isNaN)
    }

    func test_calculateBearing_samePoint_doesNotCrash() {
        let point = Coordinate(latitude: 37.5, longitude: -122.0)
        XCTAssertFalse(manager.calculateBearing(from: point, to: point).isNaN)
    }

    func test_calculateBearing_resultIsInValidRange() {
        let bearing = manager.calculateBearing(from: Coordinate(latitude: 10, longitude: 20), to: Coordinate(latitude: 30, longitude: 40))
        XCTAssertTrue(bearing >= 0 && bearing < 360)
    }

    // MARK: - distanceSquared

    func test_distanceSquared_samePoint_isZero() {
        let point = Coordinate(latitude: 1, longitude: 2)
        XCTAssertEqual(manager.distanceSquared(from: point, to: point), 0)
    }

    func test_distanceSquared_differentPoints_isPositive() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 3, longitude: 4)
        XCTAssertEqual(manager.distanceSquared(from: a, to: b), 25.0, accuracy: 0.0001)
    }

    func test_distanceSquared_isSymmetric() {
        let a = Coordinate(latitude: 1, longitude: 2)
        let b = Coordinate(latitude: 4, longitude: 6)
        XCTAssertEqual(manager.distanceSquared(from: a, to: b), manager.distanceSquared(from: b, to: a))
    }

    // MARK: - resolvedRouteFloorIds

    func test_resolvedRouteFloorIds_withFloorId_includesStartFloor() {
        let coord = Coordinate(latitude: 0, longitude: 0, floorId: "floor-1")
        let result = manager.resolvedRouteFloorIds(destinationFloorIds: ["floor-2"], startCoordinate: coord)
        XCTAssertTrue(result.contains("floor-1"))
        XCTAssertTrue(result.contains("floor-2"))
    }

    func test_resolvedRouteFloorIds_nilFloorId_returnsDestinationOnly() {
        let result = manager.resolvedRouteFloorIds(destinationFloorIds: ["floor-A"], startCoordinate: Coordinate(latitude: 0, longitude: 0))
        XCTAssertEqual(result, ["floor-A"])
    }

    func test_resolvedRouteFloorIds_emptyDestinations_withFloor_returnsStartFloor() {
        let result = manager.resolvedRouteFloorIds(destinationFloorIds: [], startCoordinate: Coordinate(latitude: 0, longitude: 0, floorId: "floor-X"))
        XCTAssertEqual(result, ["floor-X"])
    }

    // MARK: - floorVisibilityState

    func test_floorVisibilityState_visible_setsTrue() {
        XCTAssertEqual(manager.floorVisibilityState(isVisible: true).visible, true)
    }

    func test_floorVisibilityState_notVisible_setsFalse() {
        XCTAssertEqual(manager.floorVisibilityState(isVisible: false).visible, false)
    }

    // MARK: - groupedDestinations

    func test_groupedDestinations_deduplicatesByNormalizedName() {
        let dests = [
            RouteDestination(id: "1", name: "Nike", targets: [], floorIds: ["f1"]),
            RouteDestination(id: "2", name: "nike", targets: [], floorIds: ["f2"]),
        ]
        XCTAssertEqual(manager.groupedDestinations(dests).count, 1)
    }

    func test_groupedDestinations_keepsDistinctNames() {
        let dests = [
            RouteDestination(id: "1", name: "Nike", targets: [], floorIds: ["f1"]),
            RouteDestination(id: "2", name: "Adidas", targets: [], floorIds: ["f2"]),
        ]
        XCTAssertEqual(manager.groupedDestinations(dests).count, 2)
    }

    func test_groupedDestinations_emptyInput_returnsEmpty() {
        XCTAssertTrue(manager.groupedDestinations([]).isEmpty)
    }

    func test_groupedDestinations_mergesFloorIds() {
        let dests = [
            RouteDestination(id: "1", name: "Nike", targets: [], floorIds: ["f1"]),
            RouteDestination(id: "2", name: "Nike", targets: [], floorIds: ["f2"]),
        ]
        let grouped = manager.groupedDestinations(dests)
        XCTAssertTrue(grouped[0].floorIds.contains("f1"))
        XCTAssertTrue(grouped[0].floorIds.contains("f2"))
    }

    // MARK: - findDestination

    func test_findDestination_exactMatch_found() {
        let dests = [RouteDestination(id: "1", name: "Nike", targets: [], floorIds: [])]
        XCTAssertNotNil(manager.findDestination(named: "Nike", in: dests))
    }

    func test_findDestination_caseInsensitive_found() {
        let dests = [RouteDestination(id: "1", name: "NIKE", targets: [], floorIds: [])]
        XCTAssertNotNil(manager.findDestination(named: "nike", in: dests))
    }

    func test_findDestination_partialMatch_found() {
        let dests = [RouteDestination(id: "1", name: "Nike Store", targets: [], floorIds: [])]
        XCTAssertNotNil(manager.findDestination(named: "Nike", in: dests))
    }

    func test_findDestination_aliasWithPipe_firstAliasMatches() {
        let dests = [RouteDestination(id: "1", name: "Nike", targets: [], floorIds: [])]
        XCTAssertNotNil(manager.findDestination(named: "Nike|Adidas", in: dests))
    }

    func test_findDestination_aliasWithPipe_secondAliasMatches() {
        let dests = [RouteDestination(id: "2", name: "Adidas", targets: [], floorIds: [])]
        XCTAssertNotNil(manager.findDestination(named: "Nike|Adidas", in: dests))
    }

    func test_findDestination_noMatch_returnsNil() {
        let dests = [RouteDestination(id: "1", name: "Zara", targets: [], floorIds: [])]
        XCTAssertNil(manager.findDestination(named: "Nike", in: dests))
    }

    func test_findDestination_emptyDestinations_returnsNil() {
        XCTAssertNil(manager.findDestination(named: "Nike", in: []))
    }

    // MARK: - nearestStoreMarker

    func test_nearestStoreMarker_emptyDetails_returnsNil() {
        XCTAssertNil(manager.nearestStoreMarker(to: Coordinate(latitude: 0, longitude: 0)))
    }

    // MARK: - restartStartSelectionAfterInvalidRoute

    func test_restartStartSelectionAfterInvalidRoute_noPendingDestinations_doesNotCrash() {
        XCTAssertNoThrow(manager.restartStartSelectionAfterInvalidRoute(reason: "test reason"))
    }

    func test_restartStartSelectionAfterInvalidRoute_withPendingDestinations_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertNoThrow(manager.restartStartSelectionAfterInvalidRoute(reason: "test"))
    }

    // MARK: - addMarkerForUserLoc

    func test_addMarkerForUserLoc_doesNotCrash() {
        let coord = Coordinate(latitude: 37.0, longitude: -122.0)
        XCTAssertNoThrow(manager.addMarkerForUserLoc(title: "Start", subtitle: nil, color: "#1871fb", target: coord))
    }

    func test_addMarkerForUserLoc_withSubtitle_doesNotCrash() {
        let coord = Coordinate(latitude: 37.0, longitude: -122.0)
        XCTAssertNoThrow(manager.addMarkerForUserLoc(title: "Start", subtitle: "Floor 1", color: "#FF0000", target: coord, compact: true))
    }

    // MARK: - _clickHandler branches (using real ClickPayload)

    func test_clickHandler_isSetAfterInit() {
        XCTAssertNotNil(manager._clickHandler)
    }

    func test_clickHandler_nilPayload_doesNotCallCallback() {
        manager._clickHandler?(nil)
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_clickHandler_emptyMarkers_noRoute_callsCallbackWithNil() {
        let payload = ClickPayload(
            coordinate: Coordinate(latitude: 0, longitude: 0),
            markers: [],
            pointerEvent: PointerEvent(button: 0)
        )
        manager._clickHandler?(payload)
        XCTAssertEqual(callbackCallCount, 1)
    }

    func test_clickHandler_awaitingStart_triggersRoute() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let payload = ClickPayload(
            coordinate: Coordinate(latitude: 1, longitude: 2),
            markers: [],
            pointerEvent: PointerEvent(button: 0)
        )
        XCTAssertNoThrow(manager._clickHandler?(payload))
    }

    func test_clickHandler_activeRoute_emptyMarkers_reroutesTappedLocation() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        // First tap: sets start (awaitingUserStartLocation becomes false)
        manager._clickHandler?(ClickPayload(coordinate: Coordinate(latitude: 0, longitude: 0), markers: [], pointerEvent: PointerEvent(button: 0)))
        // Second tap: active route + empty markers → reroute branch
        XCTAssertNoThrow(manager._clickHandler?(ClickPayload(coordinate: Coordinate(latitude: 1, longitude: 1), markers: [], pointerEvent: PointerEvent(button: 0))))
    }

    // MARK: - startRouteFromTappedCoordinate

    func test_startRouteFromTappedCoordinate_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertNoThrow(manager.startRouteFromTappedCoordinate(Coordinate(latitude: 37.0, longitude: -122.0), destinationNames: ["Nike"]))
    }

    // MARK: - drawNearestSpaceRoute

    func test_drawNearestSpaceRoute_doesNotCrash() {
        XCTAssertNoThrow(manager.drawNearestSpaceRoute(fromCoordinate: Coordinate(latitude: 37.0, longitude: -122.0), destinationNames: ["Nike"], requestID: manager.routeRequestID))
    }

    // MARK: - loadFloors + _loadFloorsCallback

    func test_loadFloors_storesCallback() {
        manager.loadFloors(requestID: manager.routeRequestID) { }
        XCTAssertNotNil(manager._loadFloorsCallback)
    }

    func test_loadFloorsCallback_success_callsCompletion() {
        var fired = false
        manager.loadFloors(requestID: manager.routeRequestID) { fired = true }
        manager._loadFloorsCallback?(.success([]))
        XCTAssertTrue(fired)
    }

    func test_loadFloorsCallback_failure_callsCompletion() {
        var fired = false
        manager.loadFloors(requestID: manager.routeRequestID) { fired = true }
        manager._loadFloorsCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        XCTAssertTrue(fired)
    }

    func test_loadFloorsCallback_staleRequestID_doesNotCallCompletion() {
        var fired = false
        manager.loadFloors(requestID: 9999) { fired = true }
        manager._loadFloorsCallback?(.success([]))
        XCTAssertFalse(fired)
    }

    // MARK: - fetchRouteCandidates callback chain

    func test_fetchRouteCandidates_storesFetchSpacesCallback() {
        manager.fetchRouteCandidates(requestID: manager.routeRequestID) { _ in }
        XCTAssertNotNil(manager._fetchSpacesCallback)
    }

    func test_fetchSpacesCallback_failure_deliversFailure() {
        var result: Result<[RouteDestination], Error>?
        manager.fetchRouteCandidates(requestID: manager.routeRequestID) { result = $0 }
        manager._fetchSpacesCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        if case .failure = result { } else { XCTFail("Expected failure") }
    }

    func test_fetchSpacesCallback_success_storesMapObjectsCallback() {
        manager.fetchRouteCandidates(requestID: manager.routeRequestID) { _ in }
        manager._fetchSpacesCallback?(.success([]))
        XCTAssertNotNil(manager._fetchMapObjectsCallback)
    }

    func test_fetchMapObjectsCallback_success_storesDoorsCallback() {
        manager.fetchRouteCandidates(requestID: manager.routeRequestID) { _ in }
        manager._fetchSpacesCallback?(.success([]))
        manager._fetchMapObjectsCallback?(.success([]))
        XCTAssertNotNil(manager._fetchDoorsCallback)
    }

    func test_fetchMapObjectsCallback_failure_storesDoorsCallback() {
        manager.fetchRouteCandidates(requestID: manager.routeRequestID) { _ in }
        manager._fetchSpacesCallback?(.success([]))
        manager._fetchMapObjectsCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        XCTAssertNotNil(manager._fetchDoorsCallback)
    }

    func test_fetchDoorsCallback_success_storesPoisCallback() {
        manager.fetchRouteCandidates(requestID: manager.routeRequestID) { _ in }
        manager._fetchSpacesCallback?(.success([]))
        manager._fetchMapObjectsCallback?(.success([]))
        manager._fetchDoorsCallback?(.success([]))
        XCTAssertNotNil(manager._fetchPoisCallback)
    }

    func test_fetchPoisCallback_success_deliversSuccessWithCombinedCandidates() {
        var result: Result<[RouteDestination], Error>?
        manager.fetchRouteCandidates(requestID: manager.routeRequestID) { result = $0 }
        manager._fetchSpacesCallback?(.success([]))
        manager._fetchMapObjectsCallback?(.success([]))
        manager._fetchDoorsCallback?(.success([]))
        manager._fetchPoisCallback?(.success([]))
        guard case .success(let candidates) = result else { XCTFail("Expected success"); return }
        XCTAssertTrue(candidates.isEmpty)
    }

    func test_fetchPoisCallback_failure_deliversEmptySuccess() {
        var result: Result<[RouteDestination], Error>?
        manager.fetchRouteCandidates(requestID: manager.routeRequestID) { result = $0 }
        manager._fetchSpacesCallback?(.success([]))
        manager._fetchMapObjectsCallback?(.success([]))
        manager._fetchDoorsCallback?(.success([]))
        manager._fetchPoisCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        guard case .success(let candidates) = result else { XCTFail("Expected success"); return }
        XCTAssertTrue(candidates.isEmpty)
    }

    // MARK: - drawNearestSpaceRoute full chain via stored callbacks

    func test_drawNearestSpaceRoute_loadFloorsCompletion_firesFetchCandidates() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawNearestSpaceRoute(fromCoordinate: Coordinate(latitude: 0, longitude: 0), destinationNames: ["Nike"], requestID: manager.routeRequestID)
        manager._loadFloorsCallback?(.success([]))
        XCTAssertNotNil(manager._fetchSpacesCallback)
    }

    func test_drawNearestSpaceRoute_fetchFailure_restartsSelection() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawNearestSpaceRoute(fromCoordinate: Coordinate(latitude: 0, longitude: 0), destinationNames: ["Nike"], requestID: manager.routeRequestID)
        manager._loadFloorsCallback?(.success([]))
        manager._fetchSpacesCallback?(.failure(RetailBrainSDKError.invalidConfiguration))
        XCTAssertEqual(callbackCallCount, 0)
    }

    func test_drawNearestSpaceRoute_fullChain_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawNearestSpaceRoute(fromCoordinate: Coordinate(latitude: 0, longitude: 0), destinationNames: ["Nike"], requestID: manager.routeRequestID)
        manager._loadFloorsCallback?(.success([]))
        manager._fetchSpacesCallback?(.success([]))
        manager._fetchMapObjectsCallback?(.success([]))
        manager._fetchDoorsCallback?(.success([]))
        manager._fetchPoisCallback?(.success([]))
        XCTAssertTrue(true)
    }

    // MARK: - Individual fetch methods

    func test_fetchSpaceCandidates_storesCallback() {
        manager.fetchSpaceCandidates(requestID: manager.routeRequestID) { _ in }
        XCTAssertNotNil(manager._fetchSpacesCallback)
    }

    func test_fetchMapObjectCandidates_storesCallback() {
        manager.fetchMapObjectCandidates(requestID: manager.routeRequestID) { _ in }
        XCTAssertNotNil(manager._fetchMapObjectsCallback)
    }

    func test_fetchDoorCandidates_storesCallback() {
        manager.fetchDoorCandidates(requestID: manager.routeRequestID) { _ in }
        XCTAssertNotNil(manager._fetchDoorsCallback)
    }

    func test_fetchPointOfInterestCandidates_storesCallback() {
        manager.fetchPointOfInterestCandidates(requestID: manager.routeRequestID) { _ in }
        XCTAssertNotNil(manager._fetchPoisCallback)
    }
}
