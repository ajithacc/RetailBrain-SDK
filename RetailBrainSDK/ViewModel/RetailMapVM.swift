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
    private var customMapId: String?
    private let isMultiFloorMode: Bool

    init(onMapLoaded: (() -> Void)? = nil, mapId: String? = nil, isMultiFloorMode: Bool = false) {
        self.onMapLoaded = onMapLoaded
        self.customMapId = mapId
        self.isMultiFloorMode = isMultiFloorMode
    }

    private(set) var _navCallback: ((StoreDetails?) -> Void)?

    private lazy var navigationManager: NavigationManager = {
        let storeSelectionHandler: (StoreDetails?) -> Void = { [weak self] storeDetails in
            self?.onStoreSelected(storeDetails)
        }
        _navCallback = storeSelectionHandler
        return NavigationManager(mapView: mapView, storeSelectCallback: storeSelectionHandler)
    }()

    func onStoreSelected(_ storeDetails: StoreDetails?) {
        DispatchQueue.main.async { [weak self] in
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

        let mapIdToLoad = customMapId ?? config.mapId

        let options = GetMapDataWithCredentialsOptions(
            key: config.apiKey,
            secret: config.apiSecret,
            mapId: mapIdToLoad
        )

        let getMapDataCompletion: (Result<Any?, Error>) -> Void = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success: self.handleMapDataSuccess()
            case .failure(let error): self.handleMapDataFailure(error)
            }
        }
        _getMapDataCallback = getMapDataCompletion
        mapView.getMapData(options: options, onResult: getMapDataCompletion)
    }

    private(set) var _getMapDataCallback: ((Result<Any?, Error>) -> Void)?

    func handleMapDataSuccess() {
        let multiFloorOptions: MultiFloorViewOptions? = isMultiFloorMode
            ? MultiFloorViewOptions(
                enabled: true,
                floorGap: nil,
                floorGapMultiplier: nil,
                floorGapFallback: nil,
                updateCameraElevationOnFloorChange: true,
                footprintColor: nil,
                footprintOpacity: nil,
                footprintOutline: nil,
                spacesOpenToBelowEnabled: nil,
                spacesOpenToBelowVisualEffectEnabled: nil,
                spacesOpenToBelowVisualEffectDarkenAmount: nil,
                spacesOpenToBelowVisualEffectDarkenUseDepth: nil,
                spacesOpenToBelowVisualEffectDesaturateAmount: nil,
                spacesOpenToBelowVisualEffectDesaturateUseDepth: nil,
                spacesOpenToBelowVisualEffectWashOutAmount: nil,
                spacesOpenToBelowVisualEffectWashOutUseDepth: nil
            )
            : nil

        let showOptions = Show3DMapOptions(
            bearing: nil,
            debug: nil,
            flipImagesToFaceCamera: nil,
            initialFloor: nil,
            injectStyles: nil,
            multiFloorView: multiFloorOptions,
            outdoorView: nil,
            pitch: nil,
            preloadFloors: nil,
            screenOffsets: nil,
            shadingAndOutlines: nil,
            style: nil,
            wallTopColor: nil,
            zoomLevel: nil
        )

        let show3dMapCompletion: (Result<Any?, Error>) -> Void = { [weak self] renderResult in
            guard let self else { return }
            switch renderResult {
            case .success: self.handleRenderSuccess()
            case .failure(let error): self.handleRenderFailure(error)
            }
        }
        _show3dMapCallback = show3dMapCompletion
        mapView.show3dMap(options: showOptions, onResult: show3dMapCompletion)
    }

    private(set) var _show3dMapCallback: ((Result<Any?, Error>) -> Void)?

    func handleMapDataFailure(_ error: Error) {
        print("Map Loading Failed")
        print(error)
        RetailBrainManager.shared.delegate?.mapDidFailToLoad(error: error)
        isLoading = false
    }

    func handleRenderSuccess() {
        print("Map Loaded Successfully")
        RetailBrainManager.shared.delegate?.mapDidLoad()
        onMapLoaded?()
        isLoading = false
    }

    func handleRenderFailure(_ error: Error) {
        print("Map rendering failed")
        print(error)
        RetailBrainManager.shared.delegate?.mapDidFailToLoad(error: error)
        isLoading = false
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
