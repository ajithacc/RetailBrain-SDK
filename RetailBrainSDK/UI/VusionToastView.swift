//
//  VusionToastView.swift
//  RetailBrainSDK
//
//  Created by GitHub Copilot on 16/07/26.
//

import SwiftUI

struct VusionToastView: View {
    let content: VusionToastContent
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    switch content {
                    case .locationUpdate(let update):
                        locationUpdateView(update)
                    case .status(let status):
                        statusUpdateView(status)
                    }
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(12)
        .padding(16)
        .frame(maxWidth: .infinity)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    @ViewBuilder
    private func locationUpdateView(_ update: VusionLocationUpdate) -> some View {
        Text("Vusion Location Updated")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
        
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Aisle:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text(update.aisleName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Modular:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text(update.modularName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Device:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text(update.deviceId)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            HStack {
                Text("RSSI:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                Text("\(update.rssi) dBm")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }
    
    @ViewBuilder
    private func statusUpdateView(_ status: VusionStatusUpdate) -> some View {
        switch status.status {
        case .initializing:
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                Text("Initializing Vusion...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        case .initialized:
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("Vusion Initialized")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        case .trackingLocationUpdates:
            HStack(spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tracking Started")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Location tracking is now active")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        case .error(let message):
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vusion Error")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        switch content {
        case .status(let statusUpdate):
            switch statusUpdate.status {
            case .error:
                return Color.red
            case .initialized:
                return Color.green
            case .trackingLocationUpdates:
                return Color.blue
            case .initializing:
                return Color.purple
            }
        case .locationUpdate:
            return Color.purple
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        VusionToastView(
            content: .locationUpdate(
                VusionLocationUpdate(
                    aisleName: "Electronics",
                    modularName: "Modular-01",
                    deviceId: "device-12345",
                    rssi: -65
                )
            ),
            onDismiss: {}
        )
        
        VusionToastView(
            content: .status(VusionStatusUpdate(status: .initialized)),
            onDismiss: {}
        )
        
        VusionToastView(
            content: .status(VusionStatusUpdate(status: .error("Failed to connect"))),
            onDismiss: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
