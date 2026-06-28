//
//  SessionDetailView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct SessionDetailView: View {
    let session: SessionData
    let readings: [SessionReadingRecord]

    private var tempCount: Int {
        readings.filter { $0.ensembleType == "01" }.count
    }

    private var imuCount: Int {
        readings.filter { $0.ensembleType == "0C" }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)

                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Duration", value: session.formattedDuration)
                    DetailRow(label: "Samples", value: "\(readings.count)")
                    DetailRow(label: "Temp rows", value: "\(tempCount)")
                    DetailRow(label: "IMU rows", value: "\(imuCount)")
                    DetailRow(
                        label: "Avg Temp",
                        value: session.averageTemp.map { String(format: "%.1f°F", $0) } ?? "N/A"
                    )
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
            serverId: 1,
            startedAt: Date(),
            endedAt: Date(),
            duration: 3600,
            samplesCollected: 150,
            averageTemp: 72.5,
            deviceName: "Smart Fin"
        ),
        readings: []
    )
}
