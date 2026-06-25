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
    
    public init(mapView: MapView, storeSelectCallback: @escaping StoreSelectCallback) {
        self.mapView = mapView
        self.storeSelectCallback = storeSelectCallback
        registerMarkerTapHandler()
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
    
    // MARK: - Public Route Drawing Methods
    
    /// Draw route from entrance/office to nearest item, then to other items in sequence.
    public func drawNearestItemRoute(
        fromLocationName entranceLocationName: String,
        destinationNames: [String]
    ) {
        guard !destinationNames.isEmpty else {
            print("No destinations provided")
            return
        }

        mapView.mapData.getByType(.enterpriseLocation) { [weak self] (locationsResult: Result<[EnterpriseLocation], Error>) in
            guard let self else { return }

            if case .success(let locations) = locationsResult, !locations.isEmpty {
                let destinations = self.groupedDestinations(
                    locations.map {
                        RouteDestination(id: $0.id, name: $0.name, targets: [.enterpriseLocation($0)])
                    }
                )
                self.drawNearestRoute(
                    fromLocationName: entranceLocationName,
                    destinationNames: destinationNames,
                    allDestinations: destinations,
                    dataSourceName: "enterprise locations"
                )
                return
            }

            self.drawNearestSpaceRoute(
                fromLocationName: entranceLocationName,
                destinationNames: destinationNames
            )
        }
    }
    
    private func drawNearestSpaceRoute(
        fromLocationName entranceLocationName: String,
        destinationNames: [String]
    ) {
        mapView.mapData.getByType(.space) { [weak self] (spacesResult: Result<[Space], Error>) in
            guard let self else { return }

            switch spacesResult {
            case .success(let spaces):
                var candidates = spaces.map {
                    RouteDestination(id: $0.id, name: $0.name, targets: [.space($0)])
                }

                self.mapView.mapData.getByType(.mapObject) { [weak self] (objectsResult: Result<[MapObject], Error>) in
                    guard let self else { return }

                    if case .success(let objects) = objectsResult {
                        candidates.append(contentsOf: objects.map {
                            RouteDestination(id: $0.id, name: $0.name, targets: [.mapObject($0)])
                        })
                    }

                    self.mapView.mapData.getByType(.door) { [weak self] (doorsResult: Result<[Door], Error>) in
                        guard let self else { return }

                        if case .success(let doors) = doorsResult {
                            candidates.append(contentsOf: doors.map {
                                RouteDestination(id: $0.id, name: $0.name, targets: [.door($0)])
                            })
                        }

                        self.mapView.mapData.getByType(.pointOfInterest) { [weak self] (poisResult: Result<[PointOfInterest], Error>) in
                            guard let self else { return }

                            if case .success(let pois) = poisResult {
                                candidates.append(contentsOf: pois.map {
                                    RouteDestination(id: $0.id, name: $0.name, targets: [.coordinate($0.coordinate)])
                                })
                            }

                            self.drawNearestRoute(
                                fromLocationName: entranceLocationName,
                                destinationNames: destinationNames,
                                allDestinations: self.groupedDestinations(candidates),
                                dataSourceName: "spaces, map objects, doors, and points of interest"
                            )
                        }
                    }
                }
            case .failure(let error):
                print("getByType space error: \(error)")
            }
        }
    }

    private func drawNearestRoute(
        fromLocationName entranceLocationName: String,
        destinationNames: [String],
        allDestinations: [RouteDestination],
        dataSourceName: String
    ) {
        guard !allDestinations.isEmpty else {
            print("No routeable \(dataSourceName) found")
            return
        }

        let entranceLocation = findDestination(named: entranceLocationName, in: allDestinations)
            ?? allDestinations.first

        guard let entranceLocation else { return }

        if entranceLocation.name.lowercased() != entranceLocationName.lowercased() {
            print("Could not find entrance location: \(entranceLocationName). Using \(entranceLocation.name) as route origin.")
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

        buildNearestRoute(
            from: entranceLocation.targets,
            remainingDestinations: destinations,
            selectedLegs: []
        ) { [weak self] legs in
            self?.drawColoredRoute(legs: legs)
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
    
    /// Draw multi-stop route through specified locations
    public func drawMultiStopRoute(through locationNames: [String]) {
        guard locationNames.count >= 2 else { return }
        
        mapView.mapData.getByType(.enterpriseLocation) { [weak self] (result: Result<[EnterpriseLocation], Error>) in
            guard let self else { return }
            
            switch result {
            case .success(let locations):
                let routeLocations = locationNames.compactMap { name in
                    locations.first { $0.name == name }
                }
                
                guard routeLocations.count == locationNames.count else {
                    let foundNames = Set(routeLocations.map { $0.name })
                    let missingNames = locationNames.filter { !foundNames.contains($0) }
                    print("Could not find route locations: \(missingNames.joined(separator: ", "))")
                    return
                }
                
                guard let origin = routeLocations.first else { return }
                let destinations = routeLocations.dropFirst().map { location in
                    MultiDestinationTarget.single(.enterpriseLocation(location))
                }
                
                self.mapView.mapData.getDirectionsMultiDestination(
                    from: .enterpriseLocation(origin),
                    to: Array(destinations)
                ) { [weak self] directionsResult in
                    guard let self else { return }
                    
                    switch directionsResult {
                    case .success(let directions):
                        guard let directions, !directions.isEmpty else {
                            print("No multi-stop directions found")
                            return
                        }
                        self.draw(directionsList: directions)
                    case .failure(let error):
                        print("getDirectionsMultiDestination error: \(error)")
                    }
                }
                
            case .failure(let error):
                print("getByType enterpriseLocation error: \(error)")
            }
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
    
    private func draw(directions: Directions) {
        let pathOptions = AddPathOptions(interactive: true)
        let navigationOptions = NavigationOptions(pathOptions: pathOptions)
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.navigation.draw(
            directions: directions,
            options: navigationOptions
        ) { _ in }
    }
    
    private func draw(directionsList: [Directions]) {
        let pathOptions = AddPathOptions(interactive: true)
        let navigationOptions = NavigationOptions(pathOptions: pathOptions)
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.navigation.draw(
            directions: directionsList,
            options: navigationOptions
        ) { _ in }
    }
    
    private func drawColoredRoute(legs: [RouteLeg]) {
        guard !legs.isEmpty else { return }
        
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        
        print("drawColoredRoute: Drawing \(legs.count) legs")
        
        // Draw paths for each leg with alternating colors
        for (index, leg) in legs.enumerated() {
            let color = index == 0 ? "#1871fb" : "#d92d20"
            let coordinateCount = leg.directions.coordinates.count
            
            guard coordinateCount > 0 else {
                print("Warning: Empty coordinates for leg \(index)")
                continue
            }
            
            print("Leg \(index): Destination=\(leg.destination.name), Coordinates=\(coordinateCount), Color=\(color)")
            
            let pathOptions = AddPathOptions(color: color)
            
            mapView.paths.add(
                coordinates: leg.directions.coordinates,
                options: pathOptions
            ) { result in
                switch result {
                case .success:
                    print("✓ Path added for leg \(index)")
                case .failure(let error):
                    print("✗ Error adding path for leg \(index): \(error)")
                }
            }
        }
        
        addRouteMarkers(for: legs)
        focusCamera(on: legs)
    }
    
    // MARK: - Marker Management
    
    private func addRouteMarkers(for legs: [RouteLeg]) {
        guard let firstCoordinate = legs.first?.directions.coordinates.first else {
            return
        }
        
        storeMarkerDetails = []
        
        addMarker(
            title: "",
            subtitle: nil,
            color: "#1871fb",
            target: firstCoordinate,
            compact: true
        )
        
        for (index, leg) in legs.enumerated() {
            guard let coordinate = leg.directions.coordinates.last else {
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
            
            mapView.markers.add(
                target: coordinate,
                html: markerHTML(
                    imageName: "map",
                    stopNumber: index + 1
                ),
                options: AddMarkerOptions(
                    interactive: .True,
                    rank: .tier(.alwaysVisible)
                )
            ) { result in
                switch result {
                case .success:
                    print("Marker added for \(leg.destination.name)")
                case .failure(let error):
                    print("Marker error: \(error)")
                }
            }
        }
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
                interactive: .True,
                rank: .tier(.alwaysVisible)
            )
        ) { _ in }
    }
    
    private func markerHTML(imageName: String, stopNumber: Int) -> String {
        """
        <div style="
            width:40px;
            height:40px;
            background:#d92d20;
            border-radius:20px;
            display:flex;
            align-items:center;
            justify-content:center;
            color:white;
            font-weight:bold;
            font-size:16px;
            box-shadow:0px 2px 8px rgba(0,0,0,0.2);
        ">
            \(stopNumber)
        </div>
        """
    }
    
    // MARK: - Tap Gesture Handling
    
    private func registerMarkerTapHandler() {
        mapView.on(Events.click) { [weak self] clickPayload in
            guard let self, let clickPayload else { return }
            
            guard let markers = clickPayload.markers, !markers.isEmpty else {
                self.storeSelectCallback?(nil)
                return
            }
            
            guard let markerDetails = self.nearestStoreMarker(to: clickPayload.coordinate) else { return }
            self.storeSelectCallback?(markerDetails.details)
        }
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
        let targets = legs.flatMap { leg in
            leg.directions.coordinates.map { FocusTarget.coordinate($0) }
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
        mapView.navigation.clear()
        mapView.paths.removeAll()
        mapView.markers.removeAll()
        storeMarkerDetails = []
        print("Routes cleared")
    }
}
