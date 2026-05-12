import Foundation
import Combine

/// Simple mock session manager for SwiftUI previews on watchOS.
final class MockSessionManager: ObservableObject {
    @Published var isSessionActive: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentTemperature: Double = 72.0
    @Published var samplesCollected: Int = 0
    @Published var averageTemperature: Double = 72.0
    @Published var gpsEnabled: Bool = true
    @Published var savedSessions: [SessionData] = []

    init() {
        // populate with a few sample sessions for previews
        let now = Date()
        savedSessions = (0..<6).map { i in
            SessionData(
                id: UUID(),
                serverId: i,
                startedAt: Calendar.current.date(byAdding: .day, value: -i, to: now) ?? now,
                endedAt: Calendar.current.date(byAdding: .day, value: -i, to: now) ?? now,
                duration: TimeInterval(60 * (10 + i * 5)),
                samplesCollected: 10 + i,
                averageTemp: 68.0 + Double(i),
                deviceName: "SmartFin-Preview"
            )
        }
    }

    func prepareSession(deviceName: String) {
        // no-op for preview
    }

    func startSession() {
        isSessionActive = true
        // simulate elapsed time increment in preview isn't necessary
    }

    func endSession() {
        isSessionActive = false
    }

    func reset() {
        elapsedTime = 0
        currentTemperature = 72.0
        samplesCollected = 0
        averageTemperature = 72.0
    }
}
