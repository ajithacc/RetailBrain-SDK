//
//  RetailMapView.swift
//  RetailBrainSDK
//
//  Created by ajith.a.s on 22/06/26.
//

import Foundation
import SwiftUI
import Mappedin
import UIKit

class MapViewContainer: UIView {
    let mapView: MapView
    
    init(mapView: MapView) {
        self.mapView = mapView
        super.init(frame: .zero)
        backgroundColor = .clear
        setupMapView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMapView() {
        // Try to extract UIView from MapView using reflection
        let mirror = Mirror(reflecting: mapView)
        
        for child in mirror.children {
            if let uiView = child.value as? UIView {
                addSubview(uiView)
                uiView.frame = bounds
                uiView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                return
            }
        }
        
        print("Warning: Unable to extract UIView from MapView")
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    let mapView: MapView
    
    func makeUIView(context: Context) -> MapViewContainer {
        return MapViewContainer(mapView: mapView)
    }
    
    func updateUIView(_ uiView: MapViewContainer, context: Context) {
        // Update logic if necessary
    }
}

public struct RetailMapView: View {

    @StateObject private var viewModel = RetailMapViewModel()

    public init() {}

    public var body: some View {

        ZStack {

            MapViewRepresentable(mapView: viewModel.mapView)

            if viewModel.isLoading {
                ProgressView()
            }
        }
        .onAppear {
            viewModel.loadMap()
        }
    }
}
