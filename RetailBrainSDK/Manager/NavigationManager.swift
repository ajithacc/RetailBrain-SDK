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

// MARK: - Route Leg Model

private struct RouteDestination {
    let id: String
    let name: String
    let targets: [NavigationTarget]
}

private struct RouteLeg {
    let destination: RouteDestination
    let directions: Directions
    let distance: Double
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
    private var destinationMarkerImageBase64: String?
    
    private var pendingDestinationNames: [String]? = nil
    private var awaitingUserStartLocation: Bool = false
    private var selectedStartCoordinate: Coordinate?
    private var routeRequestID = 0
    private let routeLegAnimationDelay: TimeInterval = 1.1
    
    public init(mapView: MapView, storeSelectCallback: @escaping StoreSelectCallback) {
        self.mapView = mapView
        self.storeSelectCallback = storeSelectCallback
        registerMarkerTapHandler()
    }
    
    // MARK: - Public routeMethod to prepare for drawing route with user interaction
    
    public func prepareToDrawRoute(destinationNames: [String]) {
        guard !destinationNames.isEmpty else { return }
        routeRequestID += 1
        pendingDestinationNames = destinationNames
        awaitingUserStartLocation = true
        selectedStartCoordinate = nil
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
    }
    
    // MARK: - Tap Gesture Handling in MapView
    
    private func registerMarkerTapHandler() {
        mapView.on(Events.click) { [weak self] clickPayload in
            guard let self, let clickPayload else { return }
            
            if let destinations = self.pendingDestinationNames {
                let coordinate = clickPayload.coordinate
                self.awaitingUserStartLocation = false
                self.startRouteFromTappedCoordinate(coordinate, destinationNames: destinations)
                return
            }
            
            guard let markers = clickPayload.markers, !markers.isEmpty else {
                self.storeSelectCallback?(nil)
                return
            }
            
            let coordinate = clickPayload.coordinate
            
            if let markerDetails = self.nearestStoreMarker(to: coordinate) {
                self.storeSelectCallback?(markerDetails.details)
                return
            }
            
            // If no destination marker found, treat as deselect
            self.storeSelectCallback?(nil)
        }
    }
    
    // MARK: - Intial Marker Added and Route Drawing
    
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
    // MARK: - Intial Marker UI
    
    private func addMarkerForUserLoc(
        title: String,
        subtitle: String?,
        color: String,
        target: Coordinate,
        compact: Bool = false
    ) {
        let gap = compact ? 4 : 6
        let paddingY = compact ? 2 : 4
        let paddingX = compact ? 6 : 8
        let fontSize = compact ? 11 : 12
        let badgeSize = compact ? 18 : 20
        let borderRadius = compact ? 12 : 14
        
        let subtitleHTML = subtitle.map { "<span>\($0)</span>" } ?? ""
        
        let markerHtml = """
        <div style="
            display: inline-flex;
            align-items: center;
            gap: \(gap)px;
            background: white;
            border: 2px solid \(color);
            border-radius: \(borderRadius)px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            color: #111827;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: \(fontSize)px;
            font-weight: 600;
            padding: \(paddingY)px \(paddingX)px;
            white-space: nowrap;
        ">
            <span style="
                align-items: center;
                background: \(color);
                border-radius: 50%;
                color: white;
                display: inline-flex;
                height: \(badgeSize)px;
                justify-content: center;
                min-width: \(badgeSize)px;
            ">\(title)</span>
            \(subtitleHTML)
        </div>
        """
        
        mapView.markers.add(
            target: target,
            html: markerHtml,
            options: AddMarkerOptions(
                interactive: .False,
                rank: .tier(.alwaysVisible)
            )
        ) { _ in }
    }
    
    // MARK: - Intial Route Drawing Logic using the nearest space or POI as starting point
    
    private func drawNearestSpaceRoute(
        fromCoordinate coordinate: Coordinate,
        destinationNames: [String],
        requestID: Int
    ) {
        mapView.mapData.getByType(.space) { [weak self] (spacesResult: Result<[Space], Error>) in
            guard let self, requestID == self.routeRequestID else { return }
            
            switch spacesResult {
            case .success(let spaces):
                var candidates = spaces.map {
                    RouteDestination(id: $0.id, name: $0.name, targets: [.space($0)])
                }
                
                self.mapView.mapData.getByType(.mapObject) { [weak self] (objectsResult: Result<[MapObject], Error>) in
                    guard let self, requestID == self.routeRequestID else { return }
                    
                    if case .success(let objects) = objectsResult {
                        candidates.append(contentsOf: objects.map {
                            RouteDestination(id: $0.id, name: $0.name, targets: [.mapObject($0)])
                        })
                    }
                    
                    self.mapView.mapData.getByType(.door) { [weak self] (doorsResult: Result<[Door], Error>) in
                        guard let self, requestID == self.routeRequestID else { return }
                        
                        if case .success(let doors) = doorsResult {
                            candidates.append(contentsOf: doors.map {
                                RouteDestination(id: $0.id, name: $0.name, targets: [.door($0)])
                            })
                        }
                        
                        self.mapView.mapData.getByType(.pointOfInterest) { [weak self] (poisResult: Result<[PointOfInterest], Error>) in
                            guard let self, requestID == self.routeRequestID else { return }
                            
                            if case .success(let pois) = poisResult {
                                candidates.append(contentsOf: pois.map {
                                    RouteDestination(id: $0.id, name: $0.name, targets: [.coordinate($0.coordinate)])
                                })
                            }
                            self.drawNearestRoute(
                                fromCoordinate: coordinate,
                                destinationNames: destinationNames,
                                allDestinations: self.groupedDestinations(candidates),
                                dataSourceName: "spaces, map objects, doors, and points of interest",
                                requestID: requestID
                            )
                        }
                    }
                }
            case .failure(let error):
                print(error)
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
                targets: matches.flatMap { $0.targets }
            )
        }
    }
    
    // MARK: - Drawing Nearest Route and Handling Missing Destinations
    
    private func drawNearestRoute(
        fromCoordinate coordinate: Coordinate,
        destinationNames: [String],
        allDestinations: [RouteDestination],
        dataSourceName: String,
        requestID: Int
    ) {
        guard !allDestinations.isEmpty else {
            return
        }
        
        var destinations: [RouteDestination] = []
        var missingNames: [String] = []
        
        for name in destinationNames {
            if let destination = findDestination(named: name, in: allDestinations),
               !destinations.contains(where: { $0.id == destination.id }) {
                destinations.append(destination)
            } else {
                missingNames.append(name)
            }
        }
        
        guard !destinations.isEmpty else {
            return
        }
        
        if !missingNames.isEmpty {
        }
        
        selectedStartCoordinate = coordinate
        buildRoute(
            from: [.coordinate(coordinate)],
            startCoordinate: coordinate,
            remainingDestinations: destinations,
            allowNearestSpaceFallback: true,
            requestID: requestID
        )
    }
    
    // MARK: - Finding the Destination by Name with Normalization and Partial Matching
    
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
    
    // MARK: - Brdging functions to build route and handle nearest space fallback
    
    private func buildRoute(
        from originTargets: [NavigationTarget],
        startCoordinate: Coordinate,
        remainingDestinations destinations: [RouteDestination],
        allowNearestSpaceFallback: Bool,
        requestID: Int
    ) {
        buildNearestRoute(
            from: originTargets,
            remainingDestinations: destinations,
            selectedLegs: []
        ) { [weak self] legs in
            guard let self, requestID == self.routeRequestID else { return }
            
            if legs.isEmpty, allowNearestSpaceFallback {
                self.buildRouteFromNearestSpace(
                    near: startCoordinate,
                    remainingDestinations: destinations,
                    requestID: requestID
                )
                return
            }
            
            self.drawColoredRoute(legs: legs, requestID: requestID)
        }
    }
    
    // MARK: - Private Route Drawing Methods
    
    private func buildNearestRoute(
        from currentTargets: [NavigationTarget],
        remainingDestinations: [RouteDestination],
        selectedLegs: [RouteLeg],
        completion: @escaping ([RouteLeg]) -> Void
    ) {
        guard !remainingDestinations.isEmpty else {
            completion(selectedLegs)
            return
        }
        
        var candidateLegs: [RouteLeg] = []
        var pendingDirectionsCount = remainingDestinations.count
        
        for destination in remainingDestinations {
            mapView.mapData.getDirections(
                from: currentTargets,
                to: destination.targets
            ) { [weak self] result in
                guard let self else { return }
                
                if case .success(let directions?) = result {
                    let distance = self.totalDistance(for: directions)
                    candidateLegs.append(
                        RouteLeg(
                            destination: destination,
                            directions: directions,
                            distance: distance
                        )
                    )
                } else if case .failure(let error) = result {
                    print(error)
                }
                
                pendingDirectionsCount -= 1
                
                guard pendingDirectionsCount == 0 else { return }
                guard let nearestLeg = candidateLegs.min(by: { $0.distance < $1.distance }) else {
                    completion(selectedLegs)
                    return
                }
                
                let remaining = remainingDestinations.filter { $0.name != nearestLeg.destination.name }
                self.buildNearestRoute(
                    from: nearestLeg.destination.targets,
                    remainingDestinations: remaining,
                    selectedLegs: selectedLegs + [nearestLeg],
                    completion: completion
                )
            }
        }
    }
    
    // MARK: - Function for finding nearest space and building route from it if no direct route is found from the tapped coordinate
    
    private func buildRouteFromNearestSpace(
        near coordinate: Coordinate,
        remainingDestinations destinations: [RouteDestination],
        requestID: Int
    ) {
        mapView.mapData.query.nearest(origin: coordinate, include: [.space]) { [weak self] result in
            guard let self, requestID == self.routeRequestID else { return }
            
            switch result {
            case .success(let queryResults):
                guard let nearestResult = queryResults?.first,
                      case .space(let nearestSpace) = nearestResult.feature else {
                    self.drawColoredRoute(legs: [], requestID: requestID)
                    return
                }
                
                self.buildRoute(
                    from: [.space(nearestSpace)],
                    startCoordinate: coordinate,
                    remainingDestinations: destinations,
                    allowNearestSpaceFallback: false,
                    requestID: requestID
                )
            case .failure(_):
                self.drawColoredRoute(legs: [], requestID: requestID)
            }
        }
    }
    
    // MARK: - Drawing the route with colored legs and adding markers for each destination
    
    private func drawColoredRoute(legs: [RouteLeg], requestID: Int) {
        guard requestID == routeRequestID else { return }
        guard !legs.isEmpty else {
            restartStartSelectionAfterInvalidRoute(reason: "No route legs were returned")
            return
        }
        
        for (_, leg) in legs.enumerated() {
            guard !leg.directions.coordinates.isEmpty else {
                restartStartSelectionAfterInvalidRoute(reason: "Selected start location produced an empty route leg")
                return
            }
        }
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        
        addRouteMarkers(for: legs)
        focusCamera(on: legs)
        animateRouteLegs(legs, currentIndex: 0, requestID: requestID)
    }
    
    // MARK: - Animating the route legs sequentially with a delay between each leg
    
    private func animateRouteLegs(_ legs: [RouteLeg], currentIndex index: Int, requestID: Int) {
        guard requestID == routeRequestID else { return }
        guard index < legs.count else { return }
        
        let leg = legs[index]
        let color = index == 0 ? "#1871fb" : "#9cc8ff"
        
        let pathOptions = AddPathOptions(
            animateDrawing: true,
            color: color
        )
        
        mapView.paths.add(
            coordinates: leg.directions.coordinates,
            options: pathOptions
        ) { [weak self] result in
            guard let self, requestID == self.routeRequestID else { return }
            
            switch result {
            case .success:
                let nextIndex = index + 1
                guard nextIndex < legs.count else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + self.routeLegAnimationDelay) { [weak self] in
                    guard let self, requestID == self.routeRequestID else { return }
                    self.animateRouteLegs(legs, currentIndex: nextIndex, requestID: requestID)
                }
            case .failure(let error):
                print(error)
                self.restartStartSelectionAfterInvalidRoute(reason: "Route drawing failed")
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
        print(reason)
    }
    
    // MARK: - Marker SetUp for each stops
    
    private func addRouteMarkers(for legs: [RouteLeg]) {
        guard let firstCoordinate = legs.first?.directions.coordinates.first else {
            return
        }
        
        storeMarkerDetails = []
        
        let startMarkerCoordinate = selectedStartCoordinate ?? firstCoordinate
        addMarkerForUserLoc(
            title: "",
            subtitle: nil,
            color: "#1871fb",
            target: startMarkerCoordinate,
            compact: true
        )
        for leg in legs {
            
            guard let coordinate = leg.directions.coordinates.last else {
                continue
            }
            if coordinate.latitude == startMarkerCoordinate.latitude && coordinate.longitude == startMarkerCoordinate.longitude {
                continue
            }
            storeMarkerDetails.append(
                StoreMarkerDetails(
                    details: StoreDetails(
                        name: leg.destination.name,
                        imageName: "",
                        locationName: leg.destination.name,
                        spaceId: leg.destination.id,
                        coordinates: (coordinate.latitude, coordinate.longitude)
                    ),
                    coordinate: coordinate
                )
            )
            
            // Add custom marker with image only, no overlay, centered anchor, data attribute with destination id
            let html = customDestinationMarkerHTML(imageSrc: "", destinationId: leg.destination.id)
            
            mapView.markers.add(
                target: coordinate,
                html: html,
                options: AddMarkerOptions(
                    interactive: .True,
                    rank: .tier(.alwaysVisible)
                )
            ) { result in
                switch result {
                case .success:
                    print("Custom destination marker added for \(leg.destination.name)")
                case .failure(let error):
                    print("Marker error: \(error)")
                }
            }
        }
    }
    
    // MARK: - Customisation of existing marker
    
    private func customDestinationMarkerHTML(
        imageSrc: String,
        destinationId: String,
        color: String = "#d92d20"
    ) -> String {
        
        return """
        <div style="width:45px;height:57px;position:relative;">
            <svg
                xmlns="http://www.w3.org/2000/svg"
                xmlns:xlink="http://www.w3.org/1999/xlink"
                width="45"
                height="57"
                viewBox="0 0 79 91"
                preserveAspectRatio="xMidYMid meet"
                style="position:absolute; left:0; top:-28.5px;">
        
                <path
                    d="M59.609,57.75C71.947,45.453 71.98,25.482 59.683,13.144C47.386,0.805 27.415,0.772 15.077,13.069C2.739,25.366 2.705,45.337 15.002,57.675L27.907,70.624C33.077,75.811 41.473,75.825 46.66,70.655L59.609,57.75Z"
                    fill="\(color)" />
        
                <path
                    d="M59.329,13.496C47.227,1.354 27.573,1.321 15.43,13.423C3.287,25.525 3.254,45.179 15.356,57.322L28.261,70.27C33.236,75.262 41.315,75.276 46.307,70.301L59.255,57.396C71.398,45.294 71.431,25.639 59.329,13.496Z"
                    fill="none"
                    stroke="#FFFFFF"
                    stroke-width="1"/>
        
                <clipPath id="cp\(destinationId)">
                    <circle
                        cx="37.3"
                        cy="35.4"
                        r="24"/>
                </clipPath>
        
                <image
                    href="\(imageSrc)"
                    x="13.3"
                    y="11.4"
                    width="48"
                    height="48"
                    clip-path="url(#cp\(destinationId))"/>
        
                <path
                    d="M37.301,85.867m-4.5,0a4.5,4.5 0,1 1,9 0a4.5,4.5 0,1 1,-9 0"
                    fill="#FFFFFF"
                    stroke="\(color)"
                    stroke-width="1"/>
        
            </svg>
        </div>
        """
    }
    
    //MARK: - Auxiliary Methods for Finding Nearest Store Marker and Calculating Distances
    
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
    
    private func focusCamera(on legs: [RouteLeg]) {
        var targets = legs.flatMap { leg in
            leg.directions.coordinates.map { FocusTarget.coordinate($0) }
        }
        if let selectedStartCoordinate {
            targets.append(.coordinate(selectedStartCoordinate))
        }
        guard !targets.isEmpty else { return }
        mapView.camera.focusOn(targets: targets)
    }
    
    private func totalDistance(for directions: Directions) -> Double {
        directions.instructions.reduce(0) { total, instruction in
            total + instruction.distance
        }
    }
    
    //MARK: - Helper Methods
    
    public func clearRoutes() {
        routeRequestID += 1
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        pendingDestinationNames = nil
        awaitingUserStartLocation = false
        selectedStartCoordinate = nil
    }
    
    //MARK: - Helper Methods
    
    private func normalizedRouteName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

