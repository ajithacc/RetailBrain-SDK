//
//  NavigationManager.swift
//  RetailBrainSDK
//
//  Created by ajith.a.s on 24/06/26.
//

import Foundation
import Mappedin
import UIKit

public typealias StoreSelectCallback = (StoreDetails?) -> Void

// MARK: - Camera Constants

private let CAMERA_ZOOM: Double = 19.0
private let CAMERA_PITCH: Double = 0.0
private let MULTI_FLOOR_CAMERA_PITCH: Double = 45.0
private let DEFAULT_BEARING: Double = 0.0
private let BEARING_OFFSET: Double = -33.0

// MARK: - Data Models

private struct RouteDestination {
    let id: String
    let name: String
    let targets: [NavigationTarget]
    let floorIds: Set<String>
}

private struct StoreMarkerDetails {
    let details: StoreDetails
    let coordinate: Coordinate
}

// MARK: - Navigation Manager

public class NavigationManager {
    
    private let mapView: MapView
    private var storeSelectCallback: StoreSelectCallback?
    private var storeMarkerDetails: [StoreMarkerDetails] = []
    
    private var pendingDestinationNames: [String]? = nil
    private var awaitingUserStartLocation: Bool = false
    private var selectedStartCoordinate: Coordinate?
    private var routeRequestID = 0
    
    private var availableFloors: [Floor] = []
    private var currentActiveFloors: Set<String> = []
    private var isMultiFloorRouteActive = false
    
    public init(mapView: MapView, storeSelectCallback: @escaping StoreSelectCallback) {
        self.mapView = mapView
        self.storeSelectCallback = storeSelectCallback
        registerMarkerTapHandler()
    }
    
    // MARK: - Public API
    
    public func prepareToDrawRoute(destinationNames: [String]) {
        guard !destinationNames.isEmpty else { return }
        routeRequestID += 1
        pendingDestinationNames = destinationNames
        awaitingUserStartLocation = true
        selectedStartCoordinate = nil
        isMultiFloorRouteActive = false
        currentActiveFloors = []
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
    }
    
    public func clearRoutes() {
        routeRequestID += 1
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        pendingDestinationNames = nil
        awaitingUserStartLocation = false
        selectedStartCoordinate = nil
        isMultiFloorRouteActive = false
        currentActiveFloors = []
    }
    
    // MARK: - Tap Gesture Handling
    
    private func registerMarkerTapHandler() {
        mapView.on(Events.click) { [weak self] clickPayload in
            guard let self, let clickPayload else { return }

            let tappedMarkers = clickPayload.markers ?? []
            
            // Only treat a tap as route-start selection while explicitly waiting for start input.
            if self.awaitingUserStartLocation,
               let destinations = self.pendingDestinationNames {
                let coordinate = clickPayload.coordinate
                self.awaitingUserStartLocation = false
                self.startRouteFromTappedCoordinate(coordinate, destinationNames: destinations)
                return
            }

            // During an active route, reroute only when tapping open map space.
            // Marker taps (for example floor transition arrows) should keep current route flow.
            if let destinations = self.pendingDestinationNames,
               tappedMarkers.isEmpty {
                self.startRouteFromTappedCoordinate(clickPayload.coordinate, destinationNames: destinations)
                return
            }
            
            guard !tappedMarkers.isEmpty else {
                self.storeSelectCallback?(nil)
                return
            }
            
            let coordinate = clickPayload.coordinate
            
            if let markerDetails = self.nearestStoreMarker(to: coordinate) {
                self.storeSelectCallback?(markerDetails.details)
                return
            }
            
            self.storeSelectCallback?(nil)
        }
    }
    
    // MARK: - Route Initialization
    
    private func startRouteFromTappedCoordinate(_ coordinate: Coordinate, destinationNames: [String]) {
        routeRequestID += 1
        selectedStartCoordinate = coordinate
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        addMarkerForUserLoc(
            title: "",
            subtitle: nil,
            color: "#1871fb",
            target: coordinate,
            compact: true
        )
        drawNearestSpaceRoute(fromCoordinate: coordinate, destinationNames: destinationNames, requestID: routeRequestID)
    }
    
    // MARK: - Initial Marker Setup
    
    private func addMarkerForUserLoc(
        title: String,
        subtitle: String?,
        color: String,
        target: Coordinate,
        compact: Bool = false
    ) {
        let markerHtml = MarkerHTMLGenerator.startMarkerHTML(
            title: title,
            subtitle: subtitle,
            color: color,
            compact: compact
        )
        
        mapView.markers.add(
            target: target,
            html: markerHtml,
            options: AddMarkerOptions(
                interactive: .False,
                rank: .tier(.alwaysVisible)
            )
        ) { _ in }
    }
    
    // MARK: - Floor Loading for Multi-Floor Support
    
    private func loadFloors(requestID: Int, completion: @escaping () -> Void) {
        mapView.mapData.getByType(.floor) { [weak self] (floorsResult: Result<[Floor], Error>) in
            guard let self, requestID == self.routeRequestID else { return }
            
            if case .success(let floors) = floorsResult {
                self.availableFloors = floors
            } else {
                self.availableFloors = []
            }
            
            completion()
        }
    }
    
    // MARK: - Fetching Spaces, MapObjects, Doors, and POIs for Route Calculation
    
    private func drawNearestSpaceRoute(
        fromCoordinate coordinate: Coordinate,
        destinationNames: [String],
        requestID: Int
    ) {
        loadFloors(requestID: requestID) { [weak self] in
            guard let self, requestID == self.routeRequestID else { return }
            
            self.mapView.mapData.getByType(.space) { [weak self] (spacesResult: Result<[Space], Error>) in
                guard let self, requestID == self.routeRequestID else { return }

                switch spacesResult {
                case .success(let spaces):
                    var candidates = spaces.map {
                        RouteDestination(
                            id: $0.id,
                            name: $0.name,
                            targets: [.space($0)],
                            floorIds: [$0.floor]
                        )
                    }

                    self.mapView.mapData.getByType(.mapObject) { [weak self] (objectsResult: Result<[MapObject], Error>) in
                        guard let self, requestID == self.routeRequestID else { return }

                        if case .success(let objects) = objectsResult {
                            candidates.append(contentsOf: objects.map {
                                RouteDestination(
                                    id: $0.id,
                                    name: $0.name,
                                    targets: [.mapObject($0)],
                                    floorIds: [$0.floor]
                                )
                            })
                        }

                        self.mapView.mapData.getByType(.door) { [weak self] (doorsResult: Result<[Door], Error>) in
                            guard let self, requestID == self.routeRequestID else { return }

                            if case .success(let doors) = doorsResult {
                                candidates.append(contentsOf: doors.map {
                                    RouteDestination(
                                        id: $0.id,
                                        name: $0.name,
                                        targets: [.door($0)],
                                        floorIds: [$0.floor]
                                    )
                                })
                            }

                            self.mapView.mapData.getByType(.pointOfInterest) { [weak self] (poisResult: Result<[PointOfInterest], Error>) in
                                guard let self, requestID == self.routeRequestID else { return }

                                if case .success(let pois) = poisResult {
                                    candidates.append(contentsOf: pois.map {
                                        var poiFloorIds: Set<String> = [$0.floor]
                                        if let coordinateFloorId = $0.coordinate.floorId {
                                            poiFloorIds.insert(coordinateFloorId)
                                        }

                                        return RouteDestination(
                                            id: $0.id,
                                            name: $0.name,
                                            targets: [.coordinate($0.coordinate)],
                                            floorIds: poiFloorIds
                                        )
                                    })
                                }

                                self.initializeOptimalRouting(
                                    fromCoordinate: coordinate,
                                    destinationNames: destinationNames,
                                    allDestinations: self.groupedDestinations(candidates),
                                    requestID: requestID
                                )
                            }
                        }
                    }

                case .failure:
                    self.restartStartSelectionAfterInvalidRoute(
                        reason: "Failed to load map entities"
                    )
                }
            }
        }
    }
    
    // MARK: - Destination Grouping and Lookup
    
    private func groupedDestinations(_ destinations: [RouteDestination]) -> [RouteDestination] {
        let grouped = Dictionary(grouping: destinations) { normalizedRouteName($0.name) }
        
        return grouped.values.compactMap { matches in
            guard let first = matches.first else { return nil }
            return RouteDestination(
                id: matches.map { $0.id }.joined(separator: ","),
                name: first.name,
                targets: matches.flatMap { $0.targets },
                floorIds: Set(matches.flatMap { $0.floorIds })
            )
        }
    }
    
    // MARK: - Optimal Routing Initialization
    
    private func initializeOptimalRouting(
        fromCoordinate coordinate: Coordinate,
        destinationNames: [String],
        allDestinations: [RouteDestination],
        requestID: Int
    ) {
        guard !allDestinations.isEmpty else {
            return
        }
        
        var destinations: [RouteDestination] = []
        
        for name in destinationNames {
            if let destination = findDestination(named: name, in: allDestinations),
               !destinations.contains(where: { $0.id == destination.id }) {
                destinations.append(destination)
            }
        }
        
        guard !destinations.isEmpty else {
            return
        }

        let destinationFloorIds = Set(destinations.flatMap { $0.floorIds })
        let resolvedFloorIds = resolvedRouteFloorIds(
            destinationFloorIds: destinationFloorIds,
            startCoordinate: coordinate
        )

        isMultiFloorRouteActive = resolvedFloorIds.count > 1
        currentActiveFloors = isMultiFloorRouteActive ? resolvedFloorIds : []
        
        selectedStartCoordinate = coordinate
        determineOptimalOrder(
            startCoordinate: coordinate,
            destinations: destinations,
            requestID: requestID
        )
    }
    
    // MARK: - Destination Lookup
    
    private func findDestination(named name: String, in destinations: [RouteDestination]) -> RouteDestination? {
        let aliases = name
            .split(separator: "|")
            .map { normalizedRouteName(String($0)) }
            .filter { !$0.isEmpty }
        
        for alias in aliases {
            if let exactMatch = destinations.first(where: { normalizedRouteName($0.name) == alias }) {
                return exactMatch
            }
        }
        
        for alias in aliases {
            if let partialMatch = destinations.first(where: { destination in
                let destinationName = normalizedRouteName(destination.name)
                return destinationName.contains(alias) || alias.contains(destinationName)
            }) {
                return partialMatch
            }
        }
        
        return nil
    }
    
    // MARK: - Optimal Route Order (Greedy Nearest-Neighbor)
    
    private func determineOptimalOrder(
        startCoordinate: Coordinate,
        destinations: [RouteDestination],
        requestID: Int
    ) {
        buildOptimalOrder(
            currentTargets: [.coordinate(startCoordinate)],
            startCoordinate: startCoordinate,
            remainingDestinations: destinations,
            orderedDestinations: [],
            requestID: requestID
        )
    }
    
    // MARK: - Optimal Route Order (Greedy Nearest-Neighbor)
    
    private func buildOptimalOrder(
        currentTargets: [NavigationTarget],
        startCoordinate: Coordinate,
        remainingDestinations: [RouteDestination],
        orderedDestinations: [RouteDestination],
        requestID: Int
    ) {
        guard !remainingDestinations.isEmpty else {
            drawMultiDestinationRoute(
                startCoordinate: startCoordinate,
                destinations: orderedDestinations,
                requestID: requestID
            )
            return
        }
        
        var candidateDirections: [(destination: RouteDestination, directions: Directions, distance: Double)] = []
        var pendingDirectionsCount = remainingDestinations.count
        
        for destination in remainingDestinations {
            mapView.mapData.getDirections(
                from: currentTargets,
                to: destination.targets
            ) { [weak self] result in
                guard let self, requestID == self.routeRequestID else { return }
                
                if case .success(let directions?) = result {
                    let distance = self.totalDistance(for: directions)
                    candidateDirections.append((destination: destination, directions: directions, distance: distance))
                }
                
                pendingDirectionsCount -= 1
                
                guard pendingDirectionsCount == 0 else { return }
                guard let nearest = candidateDirections.min(by: { $0.distance < $1.distance }) else {
                    self.drawMultiDestinationRoute(
                        startCoordinate: startCoordinate,
                        destinations: orderedDestinations,
                        requestID: requestID
                    )
                    return
                }
                
                let remaining = remainingDestinations.filter { $0.name != nearest.destination.name }
                self.buildOptimalOrder(
                    currentTargets: nearest.destination.targets,
                    startCoordinate: startCoordinate,
                    remainingDestinations: remaining,
                    orderedDestinations: orderedDestinations + [nearest.destination],
                    requestID: requestID
                )
            }
        }
    }
    
    // MARK: - Multi-Destination Route Drawing
    
    private func drawMultiDestinationRoute(
        startCoordinate: Coordinate,
        destinations: [RouteDestination],
        requestID: Int
    ) {
        guard requestID == routeRequestID else { return }
        guard !destinations.isEmpty else {
            restartStartSelectionAfterInvalidRoute(reason: "No valid destinations to route")
            return
        }
        
        let multiDestinationTargets = destinations.flatMap { destination in
            destination.targets.map { MultiDestinationTarget.single($0) }
        }
        
        mapView.mapData.getDirectionsMultiDestination(
            from: .coordinate(startCoordinate),
            to: multiDestinationTargets
        ) { [weak self] result in
            guard let self, requestID == self.routeRequestID else { return }
            
            switch result {
            case .success(let allDirections):
                guard let allDirections = allDirections, !allDirections.isEmpty else {
                    self.restartStartSelectionAfterInvalidRoute(reason: "No directions returned from multi-destination query")
                    return
                }
                
                self.renderMultiDestinationRoute(
                    allDirections: allDirections,
                    destinations: destinations,
                    startCoordinate: startCoordinate,
                    requestID: requestID
                )
            case .failure(_):
                self.restartStartSelectionAfterInvalidRoute(reason: "Multi-destination route failed")
            }
        }
    }
    
    // MARK: - Multi-Destination Route Rendering
    
    private func renderMultiDestinationRoute(
        allDirections: [Directions],
        destinations: [RouteDestination],
        startCoordinate: Coordinate,
        requestID: Int
    ) {
        guard requestID == routeRequestID else { return }
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        
        addRouteMarkers(for: allDirections, destinations: destinations, startCoordinate: startCoordinate)

        updateRouteFloorContext(
            allDirections: allDirections,
            destinations: destinations,
            startCoordinate: startCoordinate
        )
        
        if let firstLeg = allDirections.first {
            positionCamera(from: startCoordinate, firstLeg: firstLeg)
        }
        
        let navigationOptions = NavigationOptions(
            animatePathDrawing: true,
            createMarkers: NavigationOptions.CreateMarkers.withDefaults(
                connection: true,
                departure: false,
                destination: false
            ),
            inactivePathOptions: AddPathOptions(
                accentColor: "#e2e8f0",
                color: "#93c5fd",
                displayArrowsOnPath: false
            ),
            markerOptions: nil,
            pathOptions: AddPathOptions(
                accentColor: "white",
                color: "#4b90e2",
                displayArrowsOnPath: true
            ),
            setMapOnConnectionClick: true,
            setMapToDeparture: true
        )
        
        mapView.navigation.draw(directions: allDirections, options: navigationOptions) { [weak self] result in
            guard let self, requestID == self.routeRequestID else { return }
            
            switch result {
            case .success:
                self.syncActiveFloorsWithCurrentMapFloorIfNeeded()
            case .failure:
                self.restartStartSelectionAfterInvalidRoute(reason: "Failed to draw route")
            }
        }
    }
    
    // MARK: - Restarting start selection after an invalid route or error
    
    private func restartStartSelectionAfterInvalidRoute(reason: String) {
        guard let destinations = pendingDestinationNames, !destinations.isEmpty else { return }
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        selectedStartCoordinate = nil
        awaitingUserStartLocation = true
        isMultiFloorRouteActive = false
        currentActiveFloors = []
        print(reason)
    }
    
    // MARK: - Add Route Markers at Waypoints
    
    private func addRouteMarkers(
        for allDirections: [Directions],
        destinations: [RouteDestination],
        startCoordinate: Coordinate
    ) {
        storeMarkerDetails = []
        
        addMarkerForUserLoc(
            title: "",
            subtitle: nil,
            color: "#1871fb",
            target: startCoordinate,
            compact: true
        )
        
        for (index, directions) in allDirections.enumerated() {
            guard let lastCoordinate = directions.coordinates.last else { continue }
            
            if lastCoordinate.latitude == startCoordinate.latitude && lastCoordinate.longitude == startCoordinate.longitude {
                continue
            }
            
            guard index < destinations.count else { continue }
            let destination = destinations[index]
            
            storeMarkerDetails.append(
                StoreMarkerDetails(
                    details: StoreDetails(
                        name: destination.name,
                        imageName: "",
                        locationName: destination.name,
                        spaceId: destination.id,
                        coordinates: (lastCoordinate.latitude, lastCoordinate.longitude)
                    ),
                    coordinate: lastCoordinate
                )
            )
            
            let html = MarkerHTMLGenerator.customDestinationMarkerHTML(imageSrc: "", destinationId: destination.id)
            
            mapView.markers.add(
                target: lastCoordinate,
                html: html,
                options: AddMarkerOptions(
                    interactive: .True,
                    rank: .tier(.alwaysVisible)
                )
            ) { _ in }
        }
    }
    
    // MARK: - Nearest Store Marker
    
    private func nearestStoreMarker(to coordinate: Coordinate) -> StoreMarkerDetails? {
        storeMarkerDetails.min { first, second in
            distanceSquared(from: coordinate, to: first.coordinate) < distanceSquared(from: coordinate, to: second.coordinate)
        }
    }
    
    private func distanceSquared(from first: Coordinate, to second: Coordinate) -> Double {
        let latitudeDifference = first.latitude - second.latitude
        let longitudeDifference = first.longitude - second.longitude
        return latitudeDifference * latitudeDifference + longitudeDifference * longitudeDifference
    }
    
    // MARK: - Camera and Utility Methods
    
    private func positionCamera(from: Coordinate, firstLeg: Directions) {
        guard let toCoordinate = firstLeg.coordinates.last else {
            positionCameraDefault(from: from)
            return
        }
        
        let bearing = calculateBearing(from: from, to: toCoordinate)
        
        let cameraTarget = CameraTarget(
            bearing: bearing,
            center: from,
            pitch: isMultiFloorRouteActive ? MULTI_FLOOR_CAMERA_PITCH : CAMERA_PITCH,
            zoomLevel: CAMERA_ZOOM
        )
        
        mapView.camera.set(target: cameraTarget) { _ in }
    }
    
    private func positionCameraDefault(from: Coordinate) {
        let cameraTarget = CameraTarget(
            bearing: DEFAULT_BEARING,
            center: from,
            pitch: isMultiFloorRouteActive ? MULTI_FLOOR_CAMERA_PITCH : CAMERA_PITCH,
            zoomLevel: CAMERA_ZOOM
        )
        
        mapView.camera.set(target: cameraTarget) { _ in }
    }
    
    private func calculateBearing(from: Coordinate, to: Coordinate) -> Double {
        let angleDegrees = (180.0 / .pi) * atan2(
            to.longitude - from.longitude,
            to.latitude - from.latitude
        )
        let bearing = (angleDegrees + BEARING_OFFSET).truncatingRemainder(dividingBy: 360.0)
        return bearing >= 0 ? bearing : bearing + 360.0
    }
    
    // MARK: - Route Distance Calculation
    
    private func totalDistance(for directions: Directions) -> Double {
        directions.instructions.reduce(0) { total, instruction in
            total + instruction.distance
        }
    }

    private func resolvedRouteFloorIds(destinationFloorIds: Set<String>, startCoordinate: Coordinate) -> Set<String> {
        var floorIds = destinationFloorIds
        if let startFloorId = startCoordinate.floorId {
            floorIds.insert(startFloorId)
        }
        return floorIds
    }

    private func updateRouteFloorContext(
        allDirections: [Directions],
        destinations: [RouteDestination],
        startCoordinate: Coordinate
    ) {
        let directionFloorIds = Set(allDirections.flatMap { direction in
            direction.coordinates.compactMap(\.floorId)
        })
        let destinationFloorIds = Set(destinations.flatMap { $0.floorIds })

        var routeFloorIds = directionFloorIds.union(destinationFloorIds)
        if let startFloorId = startCoordinate.floorId {
            routeFloorIds.insert(startFloorId)
        }

        guard routeFloorIds.count > 1 else {
            isMultiFloorRouteActive = false
            currentActiveFloors = []
            return
        }

        isMultiFloorRouteActive = true
        currentActiveFloors = routeFloorIds

        let preferredFloorId = startCoordinate.floorId
            ?? allDirections.first?.coordinates.first?.floorId
            ?? allDirections.first?.coordinates.last?.floorId

        applyMultiFloorVisibility(
            activeFloorIds: routeFloorIds,
            focusFloorId: preferredFloorId,
            shouldSetFloor: true
        )
    }

    private func syncActiveFloorsWithCurrentMapFloorIfNeeded() {
        guard isMultiFloorRouteActive, !currentActiveFloors.isEmpty else { return }

        mapView.currentFloor { [weak self] result in
            guard let self else { return }
            if case .success(let floor?) = result {
                self.applyMultiFloorVisibility(
                    activeFloorIds: self.currentActiveFloors,
                    focusFloorId: floor.id,
                    shouldSetFloor: false
                )
            }
        }
    }

    private func applyMultiFloorVisibility(
        activeFloorIds: Set<String>,
        focusFloorId: String?,
        shouldSetFloor: Bool
    ) {
        guard !availableFloors.isEmpty else { return }

        for floor in availableFloors {
            let isVisible = activeFloorIds.contains(floor.id)
            mapView.updateState(
                floor: floor,
                state: floorVisibilityState(isVisible: isVisible)
            ) { _ in }
        }

        if shouldSetFloor,
           let focusFloorId,
           activeFloorIds.contains(focusFloorId) {
            mapView.setFloor(floorId: focusFloorId) { _ in }
        }
    }

    private func floorVisibilityState(isVisible: Bool) -> FloorUpdateState {
        FloorUpdateState(
            type: nil,
            altitude: nil,
            visible: isVisible,
            areas: nil,
            footprint: nil,
            geometry: nil,
            images: nil,
            labels: nil,
            markers: nil,
            occlusion: nil,
            paths: nil
        )
    }
    
    // MARK: - Route Name Normalization
    
    private func normalizedRouteName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

