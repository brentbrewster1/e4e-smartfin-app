//
//  ConnectingView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct ConnectingView: View {
    let deviceName: String
    let onCancel: () -> Void
    let onConnected: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Animated connecting indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .pink))
                .scaleEffect(1.5)
            
            Text("Connecting to\n\(deviceName)...")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
        .padding()
    }
}

#Preview {
    ConnectingView(
        deviceName: "Smart Fin",
        onCancel: {},
        onConnected: {}
    )
}
