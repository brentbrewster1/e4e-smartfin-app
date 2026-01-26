//
//  SurfingSession.swift
//  smartfin
//
//  Created by Smartfin AI on 1/24/26.
//

import Foundation
import SwiftData

@Model
final class SurfingSession {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var waveCount: Int
    var maxSpeed: Double // in mph
    var totalDistance: Double // in miles
    var waterTemp: Double // in Fahrenheit
    var locationName: String
    
    init(id: UUID = UUID(), startTime: Date, endTime: Date, waveCount: Int, maxSpeed: Double, totalDistance: Double, waterTemp: Double, locationName: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.waveCount = waveCount
        self.maxSpeed = maxSpeed
        self.totalDistance = totalDistance
        self.waterTemp = waterTemp
        self.locationName = locationName
    }
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

extension SurfingSession {
    static var mockData: [SurfingSession] {
        let calendar = Calendar.current
        let today = Date()
        
        return [
            SurfingSession(
                startTime: calendar.date(byAdding: .hour, value: -2, to: today)!,
                endTime: calendar.date(byAdding: .hour, value: -1, to: today)!,
                waveCount: 12,
                maxSpeed: 15.4,
                totalDistance: 2.1,
                waterTemp: 64.5,
                locationName: "Scripps Pier"
            ),
            SurfingSession(
                startTime: calendar.date(byAdding: .day, value: -1, to: today)!,
                endTime: calendar.date(byAdding: .hour, value: 2, to: calendar.date(byAdding: .day, value: -1, to: today)!)!,
                waveCount: 8,
                maxSpeed: 12.8,
                totalDistance: 1.5,
                waterTemp: 63.2,
                locationName: "Blacks Beach"
            ),
            SurfingSession(
                startTime: calendar.date(byAdding: .day, value: -3, to: today)!,
                endTime: calendar.date(byAdding: .hour, value: 1, to: calendar.date(byAdding: .day, value: -3, to: today)!)!,
                waveCount: 24,
                maxSpeed: 18.2,
                totalDistance: 3.4,
                waterTemp: 65.0,
                locationName: "Ocean Beach"
            )
        ]
    }
}
