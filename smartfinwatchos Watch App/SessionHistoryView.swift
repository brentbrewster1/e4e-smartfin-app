//
//  SessionHistoryView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct SessionHistoryView: View {
    let sessions: [SessionData]
    let onNewSession: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                if sessions.isEmpty {
                    VStack {
                        Spacer()
                        Text("No sessions yet")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 5, pinnedViews: []) {
                            ForEach(sessions.sorted(by: { $0.endedAt > $1.endedAt })) { session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    SessionRowView(session: session)
                                        .padding(.horizontal, 4).padding(.vertical, 2)
                                }
                            }
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: geometry.size.height,
                            alignment: .top
                        )
                    }
                }

                Button(action: onNewSession) {
                    Text("New Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.top, 8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }
}

#Preview {
    SessionHistoryView(
        sessions: [SessionData(
            id: -1,
            clientSessionId: UUID(),
            startedAt: Date(),
            endedAt: Date(),
            duration: 3600,
            samplesCollected: 150,
            averageTemp: 72.5,
            deviceName: "Smart Fin"
        ),
       SessionData(
           id: -1,
           clientSessionId: UUID(),
           startedAt: Date(),
           endedAt: Date(),
           duration: 3600,
           samplesCollected: 150,
           averageTemp: 72.5,
           deviceName: "Smart Fin"
       ),
        ],
        onNewSession: {}
    )
}
