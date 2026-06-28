//
//  SessionData.swift
//  smartfin
//
//  This file defines the SessionData struct, which represents session data for the app. It includes properties for session metadata, methods for formatting data, and conversion utilities for server communication.
//


import Foundation

#if os(iOS)
struct SessionData: Identifiable, Codable {
    let id: UUID
    var serverId: Int?
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    let samplesCollected: Int
    let averageTemp: Double?
    let deviceName: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: startedAt)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: startedAt)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

extension SessionData {
    func toServerSession() -> ServerSession {
        ServerSession(
            id: serverId ?? -1,
            clientSessionId: id,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            numEnsembles: samplesCollected,
            averageTemp: averageTemp
        )
    }
}
#endif