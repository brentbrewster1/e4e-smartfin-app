//
//  SessionCompleteView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct SessionCompleteView: View {
    @ObservedObject var sessionManager: SessionManager
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Session Complete")
                .font(.headline)
                .foregroundColor(.yellow)

            // Session Stats (compact)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(sessionManager.formattedElapsedTime)
                        .font(.body)
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Samples")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(sessionManager.samplesCollected)")
                        .font(.body)
                        .foregroundColor(.white)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Avg Temp")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f°F", sessionManager.averageTemperature))
                        .font(.body)
                        .foregroundColor(.white)
                }
                Spacer()
            }

            Button(action: onSave) {
                Text("Save Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}

#Preview {
    SessionCompleteView(
        sessionManager: SessionManager(),
        onSave: {}
    )
}
