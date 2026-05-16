//
//  SessionRowView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct SessionRowView: View {
    let session: SessionData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.formattedDate)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 8) {
                Text(session.formattedTime)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .layoutPriority(0)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    // Graph-style SF Symbol to represent data/packages collected
                    Image(systemName: "archivebox.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)

                    Text("\(session.samplesCollected)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .lineLimit(1)
                .layoutPriority(1)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
    }
}

#Preview {
    SessionRowView(
        session: SessionData(
            id: UUID(),
            serverId: nil,
            startedAt: Date(),
            endedAt: Date(),
            duration: 3600,
            samplesCollected: 150,
            averageTemp: 72.5,
            deviceName: "Smart Fin"
        )
    )
}
