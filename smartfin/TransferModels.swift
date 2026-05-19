//
//  TransferModels.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 5/12/26.
//

import Foundation

struct WatchTransferBatch: Codable {
    let schemaVersion: Int
    let sourcePlatform: String
    let watchInstallId: UUID
    let batchId: UUID
    let createdAt: Date
    let sessions: [WatchTransferSession]
}

struct WatchTransferSession: Codable {
    let clientSessionId: UUID
    let deviceName: String
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    let samplesCollected: Int
    let averageTemp: Double?
    let transferStatus: TransferStatus
    let ensembles: [WatchTransferEnsemble]

    func toSessionData(serverId: Int? = nil) -> SessionData {
        SessionData(
            id: clientSessionId,
            serverId: serverId,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            samplesCollected: samplesCollected,
            averageTemp: averageTemp,
            deviceName: deviceName
        )
    }
}

struct WatchTransferEnsemble: Codable {
    let ensembleClientId: UUID
    let clientSessionId: UUID
    let ensembleType: String
    let temperature: Double
    let waterStatus: String
    let geoCoordinates: String?
    let imuDataBase64: String?
    let timestamp: Date

    func toEnsembleReading(serverId: Int? = nil) -> EnsembleReading {
        EnsembleReading(
            ensembleClientId: ensembleClientId,
            id: clientSessionId,
            serverId: serverId,
            ensembleType: ensembleType,
            temperature: temperature,
            waterStatus: waterStatus,
            geoCoordinates: geoCoordinates,
            imuData: imuDataBase64.flatMap { Data(base64Encoded: $0) },
            timestamp: timestamp
        )
    }
}

enum TransferStatus: String, Codable {
    case pending
    case transferredToPhone
    case uploadedToServer
}
