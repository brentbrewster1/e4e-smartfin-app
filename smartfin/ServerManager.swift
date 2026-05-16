//
//  ServerManager.swift
//  smartfin
//
//  Created by Angie Nguyen on 5/14/26.
//

import Foundation

class ServerManager: ObservableObject {
    static let shared = ServerManager()
    private var SERVER_BASE_URL = "http://127.0.0.1:8000/api"
    
    private init() {} // This prevents creating extra instances by mistake
    
    func getSessions() async throws -> [SessionData] {

        guard let url = URL(string: SERVER_BASE_URL + "/sessions") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let serverSessions = try decoder.decode([ServerSession].self, from: data)

        return serverSessions.map { $0.toSessionData() }
    }
}

struct ServerSession: Codable {
    let id: Int
    let clientSessionId: UUID
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    let numEnsembles: Int
    let averageTemp: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case clientSessionId = "client_session_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case duration
        case numEnsembles = "num_ensembles"
        case averageTemp = "avg_tmp"
    }
}

// server session object -> watch app session object conversion
extension ServerSession {
    func toSessionData(deviceName: String = "Unknown Device") -> SessionData {
        SessionData(
            id: clientSessionId,
            serverId: id,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            samplesCollected: numEnsembles,
            averageTemp: averageTemp,
            deviceName: deviceName
        )
    }
}
