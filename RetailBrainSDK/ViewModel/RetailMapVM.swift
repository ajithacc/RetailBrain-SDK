//
//  RetailMapVM.swift
//  RetailBrainSDK
//
//  Created by ajith.a.s on 23/06/26.
//

import Foundation
import Mappedin
import SwiftUI
internal import Combine

final class RetailMapViewModel: ObservableObject {

    @Published var mapView = MapView()
    @Published var isLoading = true

    func loadMap() {

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
                    self?.isLoading = false
                }

            case .failure(let error):

                print("Map Loading Failed")
                print(error)
                self?.isLoading = false
            }
        }
    }

    deinit {
        mapView.destroy()
    }
}
