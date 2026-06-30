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

    private let onMapLoaded: (() -> Void)?

    init(onMapLoaded: (() -> Void)? = nil) {
        self.onMapLoaded = onMapLoaded
    }

    private lazy var navigationManager = NavigationManager(mapView: mapView) { [weak self] storeDetails in
        DispatchQueue.main.async {
            self?.selectedStore = storeDetails
        }
    }

    func loadMap() {
        guard let config = RetailBrainManager.shared.config else {
            print("RetailBrain Config Missing")
            RetailBrainManager.shared.delegate?.mapDidFailToLoad(error: RetailBrainSDKError.invalidConfiguration)
            isLoading = false
            return
        }

        let options = GetMapDataWithCredentialsOptions(
            key: config.apiKey,
            secret: config.apiSecret,
            mapId: config.mapId
        )

        mapView.getMapData(options: options) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                self.mapView.show3dMap(options: Show3DMapOptions()) { renderResult in
                    switch renderResult {
                    case .success:
                        print("Map Loaded Successfully")
                        RetailBrainManager.shared.delegate?.mapDidLoad()
                        self.onMapLoaded?()
                        self.navigationManager.cacheVenueData()
                        self.isLoading = false
                    case .failure(let error):
                        print("Map rendering failed")
                        print(error)
                        RetailBrainManager.shared.delegate?.mapDidFailToLoad(error: error)
                        self.isLoading = false
                    }
                }

            case .failure(let error):
                print("Map Loading Failed")
                print(error)
                RetailBrainManager.shared.delegate?.mapDidFailToLoad(error: error)
                self.isLoading = false
            }
        }
    }

    func clearSelections() {
        navigationManager.clearRoutes()
    }

    public func routeToItems(_ itemNames: [String]) {
        guard !itemNames.isEmpty else {
            print("No items provided for routing")
            return
        }

        RetailBrainManager.shared.delegate?.routeCalculationStarted()
        navigationManager.prepareToDrawRoute(destinationNames: itemNames)
    }

    deinit {
        mapView.destroy()
    }
}
