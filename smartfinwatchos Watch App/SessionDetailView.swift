//
//  SessionDetailView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct SessionDetailView: View {
    let session: SessionData
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Duration", value: session.formattedDuration)
                    DetailRow(label: "Samples", value: "\(session.samplesCollected)")
                    DetailRow(label: "Avg Temp", value: String(format: "%.1f°F", session.averageTemp))
                    DetailRow(label: "Device", value: session.deviceName)
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
    }
}

#Preview {
    SessionDetailView(
        session: SessionData(
            id: UUID(),
            date: Date(),
            duration: 3600,
            samplesCollected: 150,
            averageTemp: 72.5,
            deviceName: "Smart Fin"
        )
    )
}
