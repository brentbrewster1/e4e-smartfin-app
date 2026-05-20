//
//  ServerManager.swift
//  smartfin
//
//  Created by Angie Nguyen on 5/14/26.
//

import Foundation
import Combine

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
    
    func postSession(_ session: SessionData) async throws -> Int {
        guard let url = URL(string: SERVER_BASE_URL + "/sessions/create") else {
            throw URLError(.badURL)
        }

        // Prepare data to send
        let serverSession = session.toServerSession()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(serverSession)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData


        let (data, response) = try await URLSession.shared.data(for: request)


        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }


        let decoder = JSONDecoder()
        let createResponse = try decoder.decode(
            CreateSessionResponse.self,
            from: data
        )

        // Return server ID for uploaded session
        return createResponse.id
    }
    
    func getEnsembles() async throws -> [EnsembleReading] {
        
        guard let url = URL(string: SERVER_BASE_URL + "/ensembles") else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let serverEnsembles = try decoder.decode([ServerEnsemble].self, from: data)

        return serverEnsembles.map { $0.toEnsembleReading() }
    }
    
    func postEnsemble(
        _ ensemble: EnsembleReading,
        serverSessionId: Int
    ) async throws -> Int {

        guard let url = URL(string: SERVER_BASE_URL + "/ensembles/create") else {
            throw URLError(.badURL)
        }

        // Build payload matching server expectations
        let payload: [String: Any] = [
            "session_id": serverSessionId,
            "ensemble_type": ensemble.ensembleType,
            "temperature": ensemble.temperature,
            "water_status": ensemble.waterStatus,
            "gps": ensemble.geoCoordinates as Any,
            "imu": ensemble.imuData as Any
        ]

        let jsonData = try JSONSerialization.data(
            withJSONObject: payload
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()

        let uploadResponse = try decoder.decode(
            CreateEnsembleResponse.self,
            from: data
        )

        // Return assigned server ID for the associated session
        return uploadResponse.id
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
    func toSessionData(deviceName: String = "SmartFin") -> SessionData {
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

// Reponse models
struct CreateSessionResponse: Codable {
    let status: String
    let id: Int
}

struct CreateEnsembleResponse: Codable {
    let status: String
    let id: Int
}
