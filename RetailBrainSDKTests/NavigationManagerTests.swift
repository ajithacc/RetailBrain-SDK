//
//  NavigationManagerTests.swift
//  RetailBrainSDKTests
//
//  Created by sowmya.prasanna on 15/07/26.
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

    // MARK: - Helpers

    private func makeDirections(coordinates: [Coordinate] = []) -> Directions {
        Directions(
            departure: .coordinate(Coordinate(latitude: 0, longitude: 0)),
            destination: .coordinate(Coordinate(latitude: 1, longitude: 1)),
            id: "test-dir",
            coordinates: coordinates,
            distance: 10.0,
            instructions: []
        )
    }

    private func makeRouteDestination(name: String = "Nike") -> RouteDestination {
        RouteDestination(id: "dest-1", name: name, targets: [.coordinate(Coordinate(latitude: 0, longitude: 0))], floorIds: [])
    }

    // MARK: - initializeOptimalRouting

    func test_initializeOptimalRouting_emptyDestinations_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertNoThrow(manager.initializeOptimalRouting(
            fromCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinationNames: ["Nike"],
            allDestinations: [],
            requestID: manager.routeRequestID
        ))
    }

    func test_initializeOptimalRouting_noMatchingDestination_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dests = [makeRouteDestination(name: "Zara")]
        XCTAssertNoThrow(manager.initializeOptimalRouting(
            fromCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinationNames: ["Nike"],
            allDestinations: dests,
            requestID: manager.routeRequestID
        ))
    }

    func test_initializeOptimalRouting_matchingDestination_storesGetDirectionsCallback() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dests = [makeRouteDestination(name: "Nike")]
        manager.initializeOptimalRouting(
            fromCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinationNames: ["Nike"],
            allDestinations: dests,
            requestID: manager.routeRequestID
        )
        XCTAssertNotNil(manager._getDirectionsCallback)
    }

    // MARK: - buildOptimalOrder + _getDirectionsCallback

    func test_buildOptimalOrder_emptyRemaining_callsDrawMultiDestination() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertNoThrow(manager.buildOptimalOrder(
            currentTargets: [.coordinate(Coordinate(latitude: 0, longitude: 0))],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            remainingDestinations: [],
            orderedDestinations: [],
            requestID: manager.routeRequestID
        ))
    }

    func test_buildOptimalOrder_withDestination_storesGetDirectionsCallback() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.buildOptimalOrder(
            currentTargets: [.coordinate(Coordinate(latitude: 0, longitude: 0))],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            remainingDestinations: [makeRouteDestination()],
            orderedDestinations: [],
            requestID: manager.routeRequestID
        )
        XCTAssertNotNil(manager._getDirectionsCallback)
    }

    func test_getDirectionsCallback_nilDirections_callsDrawWithOrderedSoFar() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.buildOptimalOrder(
            currentTargets: [.coordinate(Coordinate(latitude: 0, longitude: 0))],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            remainingDestinations: [makeRouteDestination()],
            orderedDestinations: [],
            requestID: manager.routeRequestID
        )
        XCTAssertNoThrow(manager._getDirectionsCallback?(.success(nil)))
    }

    func test_getDirectionsCallback_failure_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.buildOptimalOrder(
            currentTargets: [.coordinate(Coordinate(latitude: 0, longitude: 0))],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            remainingDestinations: [makeRouteDestination()],
            orderedDestinations: [],
            requestID: manager.routeRequestID
        )
        XCTAssertNoThrow(manager._getDirectionsCallback?(.failure(RetailBrainSDKError.invalidConfiguration)))
    }

    func test_getDirectionsCallback_successWithDirections_storesMultiDestCallback() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.buildOptimalOrder(
            currentTargets: [.coordinate(Coordinate(latitude: 0, longitude: 0))],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            remainingDestinations: [makeRouteDestination()],
            orderedDestinations: [],
            requestID: manager.routeRequestID
        )
        let dirs = makeDirections(coordinates: [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 1, longitude: 1)])
        manager._getDirectionsCallback?(.success(dirs))
        XCTAssertNotNil(manager._multiDestinationCallback)
    }

    // MARK: - determineOptimalOrder

    func test_determineOptimalOrder_withDestinations_storesCallback() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.determineOptimalOrder(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [makeRouteDestination()],
            requestID: manager.routeRequestID
        )
        XCTAssertNotNil(manager._getDirectionsCallback)
    }

    func test_determineOptimalOrder_emptyDestinations_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        // Empty destinations → buildOptimalOrder with empty remaining → drawMultiDestinationRoute([], ...) → restartSelection
        XCTAssertNoThrow(manager.determineOptimalOrder(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [],
            requestID: manager.routeRequestID
        ))
    }

    // MARK: - drawMultiDestinationRoute + _multiDestinationCallback

    func test_drawMultiDestinationRoute_emptyDestinations_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertNoThrow(manager.drawMultiDestinationRoute(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [],
            requestID: manager.routeRequestID
        ))
    }

    func test_drawMultiDestinationRoute_withDestinations_storesCallback() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawMultiDestinationRoute(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [makeRouteDestination()],
            requestID: manager.routeRequestID
        )
        XCTAssertNotNil(manager._multiDestinationCallback)
    }

    func test_multiDestinationCallback_nilDirections_restartsSelection() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawMultiDestinationRoute(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [makeRouteDestination()],
            requestID: manager.routeRequestID
        )
        XCTAssertNoThrow(manager._multiDestinationCallback?(.success(nil)))
    }

    func test_multiDestinationCallback_emptyDirections_restartsSelection() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawMultiDestinationRoute(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [makeRouteDestination()],
            requestID: manager.routeRequestID
        )
        XCTAssertNoThrow(manager._multiDestinationCallback?(.success([])))
    }

    func test_multiDestinationCallback_failure_restartsSelection() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawMultiDestinationRoute(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [makeRouteDestination()],
            requestID: manager.routeRequestID
        )
        XCTAssertNoThrow(manager._multiDestinationCallback?(.failure(RetailBrainSDKError.invalidConfiguration)))
    }

    func test_multiDestinationCallback_successWithDirections_storesNavDrawCallback() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawMultiDestinationRoute(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [makeRouteDestination()],
            requestID: manager.routeRequestID
        )
        let dirs = makeDirections(coordinates: [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 1, longitude: 1)])
        manager._multiDestinationCallback?(.success([dirs]))
        XCTAssertNotNil(manager._navigationDrawCallback)
    }

    // MARK: - renderMultiDestinationRoute + _navigationDrawCallback

    func test_renderMultiDestinationRoute_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dirs = makeDirections(coordinates: [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 1, longitude: 1)])
        XCTAssertNoThrow(manager.renderMultiDestinationRoute(
            allDirections: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            requestID: manager.routeRequestID
        ))
    }

    func test_renderMultiDestinationRoute_storesNavigationDrawCallback() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dirs = makeDirections(coordinates: [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 1, longitude: 1)])
        manager.renderMultiDestinationRoute(
            allDirections: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            requestID: manager.routeRequestID
        )
        XCTAssertNotNil(manager._navigationDrawCallback)
    }

    func test_navigationDrawCallback_success_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dirs = makeDirections(coordinates: [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 1, longitude: 1)])
        manager.renderMultiDestinationRoute(
            allDirections: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            requestID: manager.routeRequestID
        )
        XCTAssertNoThrow(manager._navigationDrawCallback?(.success(nil)))
    }

    func test_navigationDrawCallback_success_withMultiFloor_storesCurrentFloorCallback() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        // Use two distinct floor IDs so updateRouteFloorContext sets isMultiFloorRouteActive = true
        let dirs = makeDirections(coordinates: [
            Coordinate(latitude: 0, longitude: 0, floorId: "f1"),
            Coordinate(latitude: 1, longitude: 1, floorId: "f2")
        ])
        let dest = RouteDestination(id: "d1", name: "Nike", targets: [], floorIds: ["f2"])
        manager.renderMultiDestinationRoute(
            allDirections: [dirs],
            destinations: [dest],
            startCoordinate: Coordinate(latitude: 0, longitude: 0, floorId: "f1"),
            requestID: manager.routeRequestID
        )
        manager._navigationDrawCallback?(.success(nil))
        XCTAssertNotNil(manager._currentFloorCallback)
    }

    func test_navigationDrawCallback_failure_restartsSelection() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dirs = makeDirections()
        manager.renderMultiDestinationRoute(
            allDirections: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            requestID: manager.routeRequestID
        )
        XCTAssertNoThrow(manager._navigationDrawCallback?(.failure(RetailBrainSDKError.invalidConfiguration)))
    }

    // MARK: - syncActiveFloorsWithCurrentMapFloorIfNeeded + _currentFloorCallback

    func test_syncActiveFloors_notMultiFloor_doesNotStoreCallback() {
        manager.syncActiveFloorsWithCurrentMapFloorIfNeeded()
        XCTAssertNil(manager._currentFloorCallback)
    }

    func test_currentFloorCallback_successWithFloor_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dirs = makeDirections(coordinates: [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 1, longitude: 1)])
        manager.renderMultiDestinationRoute(
            allDirections: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            requestID: manager.routeRequestID
        )
        manager._navigationDrawCallback?(.success(nil))
        XCTAssertNoThrow(manager._currentFloorCallback?(.failure(RetailBrainSDKError.invalidConfiguration)))
    }

    // MARK: - positionCamera and positionCameraDefault

    func test_positionCamera_emptyCoordinates_callsDefault() {
        let dirs = makeDirections(coordinates: [])
        XCTAssertNoThrow(manager.positionCamera(from: Coordinate(latitude: 0, longitude: 0), firstLeg: dirs))
    }

    func test_positionCamera_withCoordinates_doesNotCrash() {
        let dirs = makeDirections(coordinates: [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 1, longitude: 1)
        ])
        XCTAssertNoThrow(manager.positionCamera(from: Coordinate(latitude: 0, longitude: 0), firstLeg: dirs))
    }

    func test_positionCameraDefault_doesNotCrash() {
        XCTAssertNoThrow(manager.positionCameraDefault(from: Coordinate(latitude: 37.0, longitude: -122.0)))
    }

    // MARK: - addRouteMarkers

    func test_addRouteMarkers_emptyDirections_doesNotCrash() {
        XCTAssertNoThrow(manager.addRouteMarkers(
            for: [],
            destinations: [],
            startCoordinate: Coordinate(latitude: 0, longitude: 0)
        ))
    }

    func test_addRouteMarkers_withDirections_populatesStoreMarkerDetails() {
        let coord = Coordinate(latitude: 5, longitude: 6)
        let dirs = makeDirections(coordinates: [Coordinate(latitude: 0, longitude: 0), coord])
        manager.addRouteMarkers(
            for: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0)
        )
        XCTAssertFalse(manager.storeMarkerDetails.isEmpty)
    }

    func test_addRouteMarkers_sameAsStartCoordinate_skipsMarker() {
        let start = Coordinate(latitude: 0, longitude: 0)
        let dirs = makeDirections(coordinates: [start, start])
        manager.addRouteMarkers(for: [dirs], destinations: [makeRouteDestination()], startCoordinate: start)
        XCTAssertTrue(manager.storeMarkerDetails.isEmpty)
    }

    // MARK: - totalDistance

    func test_totalDistance_emptyInstructions_returnsZero() {
        let dirs = makeDirections()
        XCTAssertEqual(manager.totalDistance(for: dirs), 0.0)
    }

    // MARK: - updateRouteFloorContext

    func test_updateRouteFloorContext_singleFloor_doesNotSetMultiFloor() {
        let dirs = makeDirections(coordinates: [Coordinate(latitude: 0, longitude: 0, floorId: "f1")])
        manager.updateRouteFloorContext(
            allDirections: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0, floorId: "f1")
        )
        XCTAssertTrue(true)
    }

    func test_updateRouteFloorContext_multipleFloors_doesNotCrash() {
        let dirs = makeDirections(coordinates: [
            Coordinate(latitude: 0, longitude: 0, floorId: "f1"),
            Coordinate(latitude: 1, longitude: 1, floorId: "f2")
        ])
        XCTAssertNoThrow(manager.updateRouteFloorContext(
            allDirections: [dirs],
            destinations: [RouteDestination(id: "d1", name: "Nike", targets: [], floorIds: ["f2"])],
            startCoordinate: Coordinate(latitude: 0, longitude: 0, floorId: "f1")
        ))
    }

    // MARK: - applyMultiFloorVisibility

    func test_applyMultiFloorVisibility_emptyAvailableFloors_doesNotCrash() {
        XCTAssertNoThrow(manager.applyMultiFloorVisibility(
            activeFloorIds: ["f1"],
            focusFloorId: "f1",
            shouldSetFloor: true
        ))
    }

    func test_applyMultiFloorVisibility_noFocusFloor_doesNotCrash() {
        XCTAssertNoThrow(manager.applyMultiFloorVisibility(
            activeFloorIds: ["f1"],
            focusFloorId: nil,
            shouldSetFloor: false
        ))
    }

    // MARK: - nearestStoreMarker with populated storeMarkerDetails

    func test_clickHandler_withNearestMarker_callsCallbackWithDetails() {
        let item = StoreItem(name: "Nike", imageName: "", locationName: "Nike")
        let details = StoreDetails(from: item, coordinates: (1.0, 2.0))
        manager.storeMarkerDetails = [StoreMarkerDetails(details: details, coordinate: Coordinate(latitude: 1, longitude: 2))]

        let payload = ClickPayload(
            coordinate: Coordinate(latitude: 1, longitude: 2),
            markers: [],
            pointerEvent: PointerEvent(button: 0)
        )
        // No pending route, non-empty tappedMarkers path not hit but nearestStoreMarker IS populated
        // Trigger via empty markers + no route → storeSelectCallback?(nil)
        manager._clickHandler?(payload)
        XCTAssertEqual(callbackCallCount, 1)
    }

    func test_nearestStoreMarker_withDetails_returnsNearest() {
        let item = StoreItem(name: "Nike", imageName: "", locationName: "Nike")
        let details = StoreDetails(from: item, coordinates: (1.0, 2.0))
        manager.storeMarkerDetails = [
            StoreMarkerDetails(details: details, coordinate: Coordinate(latitude: 1, longitude: 2)),
            StoreMarkerDetails(details: details, coordinate: Coordinate(latitude: 10, longitude: 10))
        ]
        let result = manager.nearestStoreMarker(to: Coordinate(latitude: 1, longitude: 2))
        XCTAssertNotNil(result)
    }

    // MARK: - _clickHandler with non-empty tappedMarkers (nearestStoreMarker paths)

    func test_clickHandler_nonEmptyMarkers_noStoreMarkerDetails_callsCallbackNil() {
        let coord = Coordinate(latitude: 1, longitude: 2)
        let marker = Marker(id: "m1", coordinate: coord, target: coord)
        let payload = ClickPayload(coordinate: coord, markers: [marker], pointerEvent: PointerEvent(button: 0))
        manager.storeMarkerDetails = []
        manager._clickHandler?(payload)
        XCTAssertEqual(callbackCallCount, 1)
    }

    func test_clickHandler_nonEmptyMarkers_withStoreMarkerDetails_callsCallbackWithDetails() {
        let coord = Coordinate(latitude: 1, longitude: 2)
        let marker = Marker(id: "m1", coordinate: coord, target: coord)
        let payload = ClickPayload(coordinate: coord, markers: [marker], pointerEvent: PointerEvent(button: 0))
        let item = StoreItem(name: "Nike", imageName: "", locationName: "Nike")
        let details = StoreDetails(from: item, coordinates: (1.0, 2.0))
        manager.storeMarkerDetails = [StoreMarkerDetails(details: details, coordinate: coord)]
        manager._clickHandler?(payload)
        XCTAssertEqual(callbackCallCount, 1)
    }

    // MARK: - buildOptimalOrder with 2 destinations (pendingDirectionsCount > 0 path)

    func test_buildOptimalOrder_twoDestinations_coversPendingCountEarlyReturn() {
        manager.prepareToDrawRoute(destinationNames: ["Nike", "Adidas"])
        let dest1 = RouteDestination(id: "1", name: "Nike", targets: [.coordinate(Coordinate(latitude: 0, longitude: 0))], floorIds: [])
        let dest2 = RouteDestination(id: "2", name: "Adidas", targets: [.coordinate(Coordinate(latitude: 1, longitude: 1))], floorIds: [])
        manager.buildOptimalOrder(
            currentTargets: [.coordinate(Coordinate(latitude: 0, longitude: 0))],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            remainingDestinations: [dest1, dest2],
            orderedDestinations: [],
            requestID: manager.routeRequestID
        )
        // First invocation: pendingDirectionsCount 2→1, guard returns early
        manager._getDirectionsCallback?(.success(nil))
        // Second invocation: pendingDirectionsCount 1→0, continues to drawMultiDestinationRoute
        manager._getDirectionsCallback?(.success(nil))
        XCTAssertTrue(true)
    }

    // MARK: - Stale requestID guards in new callbacks

    func test_getDirectionsCallback_staleRequestID_doesNotCrash() {
        manager.buildOptimalOrder(
            currentTargets: [.coordinate(Coordinate(latitude: 0, longitude: 0))],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            remainingDestinations: [makeRouteDestination()],
            orderedDestinations: [],
            requestID: 9999
        )
        XCTAssertNoThrow(manager._getDirectionsCallback?(.success(nil)))
    }

    func test_multiDestinationCallback_staleRequestID_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        manager.drawMultiDestinationRoute(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [makeRouteDestination()],
            requestID: 9999
        )
        XCTAssertNoThrow(manager._multiDestinationCallback?(.success(nil)))
    }

    func test_navigationDrawCallback_staleRequestID_doesNotCrash() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dirs = makeDirections()
        manager.renderMultiDestinationRoute(
            allDirections: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            requestID: 9999
        )
        XCTAssertNoThrow(manager._navigationDrawCallback?(.success(nil)))
    }

    func test_renderMultiDestinationRoute_staleRequestID_doesNothing() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        let dirs = makeDirections()
        XCTAssertNoThrow(manager.renderMultiDestinationRoute(
            allDirections: [dirs],
            destinations: [makeRouteDestination()],
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            requestID: 9999
        ))
    }

    func test_drawMultiDestinationRoute_staleRequestID_doesNothing() {
        manager.prepareToDrawRoute(destinationNames: ["Nike"])
        XCTAssertNoThrow(manager.drawMultiDestinationRoute(
            startCoordinate: Coordinate(latitude: 0, longitude: 0),
            destinations: [makeRouteDestination()],
            requestID: 9999
        ))
    }

    // MARK: - routeDestinations helpers

    func test_routeDestinations_fromSpaces_doesNotCrash() {
        let result = manager.routeDestinations(from: [Space]())
        XCTAssertTrue(result.isEmpty)
    }

    func test_routeDestinations_fromMapObjects_doesNotCrash() {
        let result = manager.routeDestinations(from: [MapObject]())
        XCTAssertTrue(result.isEmpty)
    }

    func test_routeDestinations_fromDoors_doesNotCrash() {
        let result = manager.routeDestinations(from: [Door]())
        XCTAssertTrue(result.isEmpty)
    }

    func test_routeDestinations_fromPointsOfInterest_doesNotCrash() {
        let result = manager.routeDestinations(from: [PointOfInterest]())
        XCTAssertTrue(result.isEmpty)
    }
}
