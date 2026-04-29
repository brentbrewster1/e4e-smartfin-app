//
//  ReadyView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct ReadyView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // SmartFin icon
            Image(systemName: "water.waves")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Ready to start session")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onStart) {
                Text("Start Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}

#Preview {
    ReadyView(onStart: {})
}
