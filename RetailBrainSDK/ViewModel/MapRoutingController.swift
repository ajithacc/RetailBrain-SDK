//
//  MapRoutingController.swift
//  RetailBrainSDK
//
//  Created by ajith.a.s on 24/06/26.
//

import Foundation
import Combine

/// A coordinator that manages routing and communication between map view and app
/// Note: Routing is primarily handled through RetailMapViewModel directly
public final class MapRoutingController: ObservableObject {
    @Published var isMapReady = false
    private weak var viewModel: RetailMapViewModel?
    
    public init() {}
    
    /// Indicates that the map and viewmodel are ready for operations
    func markMapReady() {
        self.isMapReady = true
    }

    func attach(viewModel: RetailMapViewModel) {
        self.viewModel = viewModel
    }
    
    /// Route to specified store names
    /// Note: This is a placeholder. Actual routing is handled through RetailMapView/RetailMapViewModel
    public func routeToStores(_ storeNames: [String]) {
        print("Route requested for stores: \(storeNames.joined(separator: ", "))")
        viewModel?.routeToItems(storeNames)
    }
    
    /// Clear all routes and selections
    /// Note: This is a placeholder. Actual clearing is handled through RetailMapView/RetailMapViewModel
    public func clearRoute() {
        print("Clear route requested")
        viewModel?.clearSelections()
    }
}
