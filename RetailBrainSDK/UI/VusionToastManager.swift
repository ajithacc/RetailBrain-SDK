//
//  VusionToastManager.swift
//  RetailBrainSDK
//
//  Created by GitHub Copilot on 16/07/26.
//

import Foundation
import Combine
import SwiftUI

/// Represents toast content (either location update or status)
enum VusionToastContent {
    case locationUpdate(VusionLocationUpdate)
    case status(VusionStatusUpdate)
}

/// Manages Vusion toast notifications display
public class VusionToastManager: ObservableObject {
    
    public static let shared = VusionToastManager()
    
    @Published var toastContent: VusionToastContent?
    @Published var isShowingToast = false
    
    private var cancellables = Set<AnyCancellable>()
    private var toastTimer: Timer?
    
    // Track previous location to detect meaningful changes
    private var lastAisleName: String = ""
    private var lastModularName: String = ""
    
    private init() {
        subscribeToToastNotifications()
    }
    
    private func subscribeToToastNotifications() {
        // Subscribe to location updates
        NotificationCenter.default.publisher(for: NSNotification.Name("VusionLocationUpdateAvailable"))
            .compactMap { $0.userInfo?["update"] as? VusionLocationUpdate }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                // Show or update toast based on location changes
                self?.handleLocationUpdate(update)
            }
            .store(in: &cancellables)
        
        // Subscribe to status updates (always show)
        NotificationCenter.default.publisher(for: NSNotification.Name("VusionStatusUpdateAvailable"))
            .compactMap { $0.userInfo?["status"] as? VusionStatusUpdate }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.showToast(with: .status(status))
            }
            .store(in: &cancellables)
    }
    
    /// Handle location updates - show on first meaningful change, then update in real-time
    private func handleLocationUpdate(_ update: VusionLocationUpdate) {
        let aisleChanged = update.aisleName != lastAisleName
        let modularChanged = update.modularName != lastModularName
        
        // Update tracking values
        lastAisleName = update.aisleName
        lastModularName = update.modularName
        
        // If aisle or modular changed, show/update toast with new location
        if aisleChanged || modularChanged {
            print("[VusionToast] Location changed - Aisle: \(update.aisleName) (changed: \(aisleChanged)) | Modular: \(update.modularName) (changed: \(modularChanged)) | RSSI: \(update.rssi)")
            showToast(with: .locationUpdate(update))
        } else if isShowingToast && toastContent != nil {
            // If toast is already showing, update it with new data (RSSI changed)
            print("[VusionToast] Updating existing toast - RSSI: \(update.rssi)")
            
            // Update the content with new RSSI value
            withAnimation(.easeInOut(duration: 0.2)) {
                toastContent = .locationUpdate(update)
            }
            
            // Restart dismiss timer to extend toast duration
            toastTimer?.invalidate()
            toastTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.dismissToast()
            }
        } else {
            print("[VusionToast] Location update ignored - No active toast and same location")
        }
    }
    
    func showToast(with content: VusionToastContent) {
        toastTimer?.invalidate()
        
        // Log status toasts
        if case .status(let status) = content {
            print("[VusionToast] Displaying status: \(status.status)")
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            toastContent = content
            isShowingToast = true
        }
        
        // Auto-dismiss after appropriate duration based on content type
        let duration: TimeInterval
        switch content {
        case .status(let statusUpdate):
            switch statusUpdate.status {
            case .initializing:
                duration = 2.0 // Shorter duration for initializing
            case .initialized:
                duration = 3.0 // Show initialized status for 3 seconds
            case .trackingLocationUpdates:
                duration = 3.0 // Show tracking started for 3 seconds
            case .error:
                duration = 4.0 // Show errors longer
            }
        case .locationUpdate:
            duration = 5.0 // Location updates show for 5 seconds
        }
        
        toastTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismissToast()
        }
    }
    
    func dismissToast() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingToast = false
        }
        toastTimer?.invalidate()
        toastContent = nil
    }
    
    deinit {
        toastTimer?.invalidate()
    }
}
