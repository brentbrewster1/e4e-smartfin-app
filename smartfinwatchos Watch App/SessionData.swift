//
//  SessionData.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import Foundation

struct SessionData: Identifiable, Codable {
    let id: Int // -1 if not uploaded to server (or haven't received a response)
    let clientSessionId: UUID
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    let samplesCollected: Int
    let averageTemp: Double
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
