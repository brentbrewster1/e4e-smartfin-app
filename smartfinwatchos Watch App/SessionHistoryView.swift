//
//  SessionHistoryView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI

struct SessionHistoryView: View {
    @ObservedObject var sessionManager: SessionManager
    let onNewSession: () -> Void

    private var sessions: [SessionData] {
        sessionManager.savedSessions
    }

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
                                NavigationLink(
                                    destination: SessionDetailView(
                                        session: session,
                                        readings: sessionManager.readings(for: session.id)
                                    )
                                ) {
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
    let manager = SessionManager()
    return SessionHistoryView(sessionManager: manager, onNewSession: {})
}
