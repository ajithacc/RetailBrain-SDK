//
//  RetailMapVM.swift
//  RetailBrainSDK
//
//  Created by ajith.a.s on 23/06/26.
//

import Foundation
import Mappedin
import SwiftUI
import Combine

final class RetailMapViewModel: ObservableObject {

    @Published var mapView = MapView()
    @Published var isLoading = true
    @Published var selectedStore: StoreDetails?
    
    // Kept for backward compatibility
    @Published var availableStores: [StoreItem] = []
    @Published var selectedStores: Set<String> = []
    @Published var itemsModel: [StoreItem] = []
    
    private lazy var navigationManager = NavigationManager(mapView: mapView) { [weak self] storeDetails in
        DispatchQueue.main.async {
            self?.selectedStore = storeDetails
        }
    }

    private var onMapLoaded: (() -> Void)?
    private var hasStartedLoading = false

    init(onMapLoaded: (() -> Void)? = nil) {
        self.onMapLoaded = onMapLoaded
    }

    func loadMap() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true

        guard let config = RetailBrainManager.shared.config else {
            print("RetailBrain Config Missing")
            isLoading = false
            return
        }

        let options = GetMapDataWithCredentialsOptions(
            key: config.apiKey,
            secret: config.apiSecret,
            mapId: config.mapId
        )

        mapView.getMapData(options: options) { [weak self] result in

            switch result {

            case .success:

                self?.mapView.show3dMap(
                    options: Show3DMapOptions()
                ) { result in

                    print("Map Loaded Successfully")
                    DispatchQueue.main.async {
                        self?.onMapLoaded?()
                        self?.isLoading = false
                    }
                }

            case .failure(let error):

                print("Map Loading Failed")
                print(error)
                self?.isLoading = false
            }
        }
    }
    
    public func routeToItems(_ itemNames: [String]) {
        guard !itemNames.isEmpty else {
            print("No items provided for routing")
            return
        }
        print("Starting route to stores: \(itemNames.joined(separator: ", "))")
        navigationManager.drawNearestItemRoute(
            fromLocationName: "Office",
            destinationNames: itemNames
        )
    }

    deinit {
        mapView.destroy()
    }
}
