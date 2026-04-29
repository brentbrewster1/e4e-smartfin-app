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
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text(session.formattedTime)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(session.samplesCollected) Samples")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 6)
    }
}

#Preview {
    SessionRowView(
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
