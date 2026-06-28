//
//  ActiveSessionView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct ActiveSessionView: View {
    @ObservedObject var sessionManager: SessionManager
    let onEnd: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            
            // Timer
            Text(sessionManager.formattedElapsedTime)
                .font(.system(size: 35, weight: .medium, design: .rounded))
                .foregroundColor(.green)
                .monospacedDigit()
            
            // Temperature
            VStack(spacing: 1) {
                Text("Temp")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(String(format: "%.0f°F", sessionManager.currentTemperature))
                    .font(.system(size: 33, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(sessionManager.waterStatus.capitalized)
                .font(.caption2)
                .foregroundColor(sessionManager.waterStatus == "in-water" ? .blue : .orange)

            if let imu = sessionManager.lastIMU9, imu.count >= 3 {
                Text(String(format: "a %.1f %.1f %.1f", imu[0], imu[1], imu[2]))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Text("\(sessionManager.samplesCollected) samples")
                .font(.caption2)
                .foregroundColor(.gray)
            
            Spacer()
            
            Button(action: onEnd) {
                Text("End Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }
}

#Preview {
    ActiveSessionView(
        sessionManager: SessionManager(),
        onEnd: {}
    )
}
