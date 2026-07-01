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
        loadDestinationMarkerIcon()
    }
    
    /// Load the destination marker icon from the app's assets
    private func loadDestinationMarkerIcon() {
        // Load the "icon" image from the Demo App's asset catalog
        if let image = UIImage(named: "icon") {
            if let pngData = image.pngData() {
                destinationMarkerImageBase64 = pngData.base64EncodedString()
                print("✓ Custom destination marker icon loaded from app assets")
            }
        } else {
            print("⚠ Custom destination marker icon 'icon' not found in app assets - using fallback marker")
        }
    }
    
    /// Cache venue data and log available locations
    public func cacheVenueData() {
        mapView.mapData.getByType(.enterpriseLocation) { (result: Result<[EnterpriseLocation], Error>) in
            switch result {
            case .success(let locations):
                print("Venue cached with \(locations.count) locations")
                print("Available locations: \(locations.map { $0.name }.joined(separator: ", "))")
            case .failure(let error):
                print("Error caching venue data: \(error)")
            }
        }
    }
    
    /// Set a custom image for destination route markers
    public func setDestinationMarkerIcon(_ image: UIImage) {
        if let pngData = image.pngData() {
            destinationMarkerImageBase64 = pngData.base64EncodedString()
        }
    }
    
    /// Call this to begin route selection: stores destinations and waits for user tap to select starting point
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
        print("Tap on the map to select your starting location for the route.")
    }
    
    // MARK: - Private Route Drawing Methods
    
    private func buildNearestRoute(
        from currentTargets: [NavigationTarget],
        remainingDestinations: [RouteDestination],
        selectedLegs: [RouteLeg],
        completion: @escaping ([RouteLeg]) -> Void
    ) {
        guard !remainingDestinations.isEmpty else {
            print("✓ buildNearestRoute: All destinations visited, returned \(selectedLegs.count) legs")
            completion(selectedLegs)
            return
        }
        
        print("buildNearestRoute: Building route with \(remainingDestinations.count) remaining destinations")
        
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
                    let coordinateCount = directions.coordinates.count
                    print("✓ Got directions to \(destination.name): \(coordinateCount) coordinates, distance: \(distance)")
                    candidateLegs.append(
                        RouteLeg(
                            destination: destination,
                            directions: directions,
                            distance: distance
                        )
                    )
                } else if case .failure(let error) = result {
                    print("✗ getDirections error for \(destination.name): \(error)")
                }
                
                pendingDirectionsCount -= 1
                
                guard pendingDirectionsCount == 0 else { return }
                // find the shortest distance by comparing all values
                guard let nearestLeg = candidateLegs.min(by: { $0.distance < $1.distance }) else {
                    print("⚠ No valid legs found, completing with \(selectedLegs.count) legs")
                    completion(selectedLegs)
                    return
                }
                
                print("→ Next nearest: \(nearestLeg.destination.name) (distance: \(nearestLeg.distance))")
                
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
    
//    private func draw(directions: Directions) {
//        let pathOptions = AddPathOptions(interactive: true)
//        let navigationOptions = NavigationOptions(pathOptions: pathOptions)
//        
//        mapView.navigation.clear()
//        mapView.paths.removeAll()
//        mapView.navigation.draw(
//            directions: directions,
//            options: navigationOptions
//        ) { _ in }
//    }
//    
//    private func draw(directionsList: [Directions]) {
//        let pathOptions = AddPathOptions(interactive: true)
//        let navigationOptions = NavigationOptions(pathOptions: pathOptions)
//        
//        mapView.navigation.clear()
//        mapView.paths.removeAll()
//        mapView.navigation.draw(
//            directions: directionsList,
//            options: navigationOptions
//        ) { _ in }
//    }
    
    private func drawColoredRoute(legs: [RouteLeg], requestID: Int) {
        guard requestID == routeRequestID else { return }
        guard !legs.isEmpty else {
            restartStartSelectionAfterInvalidRoute(reason: "No route legs were returned")
            return
        }

        for (index, leg) in legs.enumerated() {
            guard !leg.directions.coordinates.isEmpty else {
                print("Warning: Empty coordinates for leg \(index)")
                restartStartSelectionAfterInvalidRoute(reason: "Selected start location produced an empty route leg")
                return
            }
        }
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        
        print("drawColoredRoute: Drawing \(legs.count) legs")
        addRouteMarkers(for: legs)
        focusCamera(on: legs)
        animateRouteLegs(legs, currentIndex: 0, requestID: requestID)
    }

    private func animateRouteLegs(_ legs: [RouteLeg], currentIndex index: Int, requestID: Int) {
        guard requestID == routeRequestID else { return }
        guard index < legs.count else { return }

        let leg = legs[index]
        let color = index == 0 ? "#1871fb" : "#9cc8ff"
        let coordinateCount = leg.directions.coordinates.count

        print("Leg \(index): Destination=\(leg.destination.name), Coordinates=\(coordinateCount), Color=\(color)")

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
                print("✓ Path added for leg \(index)")
                let nextIndex = index + 1
                guard nextIndex < legs.count else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + self.routeLegAnimationDelay) { [weak self] in
                    guard let self, requestID == self.routeRequestID else { return }
                    self.animateRouteLegs(legs, currentIndex: nextIndex, requestID: requestID)
                }
            case .failure(let error):
                print("✗ Error adding path for leg \(index): \(error)")
                self.restartStartSelectionAfterInvalidRoute(reason: "Route drawing failed")
            }
        }
    }

    private func restartStartSelectionAfterInvalidRoute(reason: String) {
        guard let destinations = pendingDestinationNames, !destinations.isEmpty else { return }

        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        selectedStartCoordinate = nil
        awaitingUserStartLocation = true
        print("\(reason). Tap another location to select your starting location for the route.")
    }
    
    // MARK: - Marker Management
    
    private func addRouteMarkers(for legs: [RouteLeg]) {
        guard let firstCoordinate = legs.first?.directions.coordinates.first else {
            return
        }
        
        storeMarkerDetails = []
        
        let startMarkerCoordinate = selectedStartCoordinate ?? firstCoordinate
        addMarker(
            title: "",
            subtitle: nil,
            color: "#1871fb",
            target: startMarkerCoordinate,
            compact: true
        )
        
        // For each destination stop except the start, add custom marker with image only and data attribute
        for leg in legs {
            // Skip the first leg's destination marker (to avoid double marker at start)
            // Actually, the first leg's first coordinate is the start, so destination markers start from leg 0's last coordinate.
            // But instructions say keep starting marker unchanged, remove default numbered markers, and add custom markers for each destination stop.
            // So we add custom markers for all legs (including first) at their last coordinate except the starting marker which was added just above.
            // The starting marker is at legs.first directions.coordinates.first, the destination markers are at the legs' last coordinates.
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
    
    private func addMarker(
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

    // MARK: - Tap Gesture Handling
    
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
                print("Selected store/aisle: \(markerDetails.details.name)")
                self.storeSelectCallback?(markerDetails.details)
                return
            }
            
            // If no destination marker found, treat as deselect
            self.storeSelectCallback?(nil)
        }
    }

    private func startRouteFromTappedCoordinate(_ coordinate: Coordinate, destinationNames: [String]) {
        routeRequestID += 1
        selectedStartCoordinate = coordinate
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        addMarker(
            title: "",
            subtitle: nil,
            color: "#1871fb",
            target: coordinate,
            compact: true
        )
        drawRouteFromCoordinate(coordinate, destinationNames: destinationNames, requestID: routeRequestID)
    }
    
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
    
    /// Clear all routes from the map
    public func clearRoutes() {
        routeRequestID += 1
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        pendingDestinationNames = nil
        awaitingUserStartLocation = false
        selectedStartCoordinate = nil
        print("Routes cleared")
    }
    
    private func drawRouteFromCoordinate(_ coordinate: Coordinate, destinationNames: [String], requestID: Int) {
        // We'll treat the coordinate as an ad-hoc starting point, and use the existing space/POI logic for destinations
        self.mapView.mapData.getByType(.enterpriseLocation) { [weak self] (locationsResult: Result<[EnterpriseLocation], Error>) in
            guard let self, requestID == self.routeRequestID else { return }
            if case .success(let locations) = locationsResult, !locations.isEmpty {
                let destinations = self.groupedDestinations(
                    locations.map {
                        RouteDestination(id: $0.id, name: $0.name, targets: [.enterpriseLocation($0)])
                    }
                )
                self.drawNearestRoute(
                    fromCoordinate: coordinate,
                    destinationNames: destinationNames,
                    allDestinations: destinations,
                    dataSourceName: "enterprise locations",
                    requestID: requestID
                )
                return
            }
            self.drawNearestSpaceRoute(fromCoordinate: coordinate, destinationNames: destinationNames, requestID: requestID)
        }
    }
    
    private func drawNearestRoute(
        fromCoordinate coordinate: Coordinate,
        destinationNames: [String],
        allDestinations: [RouteDestination],
        dataSourceName: String,
        requestID: Int
    ) {
        guard !allDestinations.isEmpty else {
            print("No routeable \(dataSourceName) found")
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
            print("Could not find any route destinations: \(destinationNames.joined(separator: ", "))")
            print("Available \(dataSourceName): \(allDestinations.map { $0.name }.joined(separator: ", "))")
            return
        }

        if !missingNames.isEmpty {
            print("Skipping route destinations not found in \(dataSourceName): \(missingNames.joined(separator: ", "))")
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
                    print("No routeable space found near selected start location")
                    self.drawColoredRoute(legs: [], requestID: requestID)
                    return
                }

                print("Using nearest routeable start space: \(nearestSpace.name) at \(nearestResult.distance)m")
                self.buildRoute(
                    from: [.space(nearestSpace)],
                    startCoordinate: coordinate,
                    remainingDestinations: destinations,
                    allowNearestSpaceFallback: false,
                    requestID: requestID
                )
            case .failure(let error):
                print("Nearest routeable start lookup failed: \(error)")
                self.drawColoredRoute(legs: [], requestID: requestID)
            }
        }
    }

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
                print("getByType space error: \(error)")
            }
        }
    }
    
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

    private func normalizedRouteName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

