//
//  MapRoutingController.swift
//  RetailBrainSDK
//
//  Created by ajith.a.s on 24/06/26.
//

import Foundation
import Combine

/// Public bridge used by the host app to send routing commands to the SDK map.
public final class MapRoutingController: ObservableObject {
    @Published public private(set) var isMapReady = false

    private weak var viewModel: RetailMapViewModel?
    private var pendingStoreNames: [String] = []

    public init() {}

    func attach(viewModel: RetailMapViewModel) {
        self.viewModel = viewModel

        if !pendingStoreNames.isEmpty {
            routeToStores(pendingStoreNames)
            pendingStoreNames.removeAll()
        }
    }

    func markMapReady() {
        isMapReady = true
    }

    /// Routes from the SDK's fixed origin location to the selected store names.
    public func routeToStores(_ storeNames: [String]) {
        guard !storeNames.isEmpty else { return }

        guard let viewModel else {
            pendingStoreNames = storeNames
            return
        }

        viewModel.routeToItems(storeNames)
    }
}
