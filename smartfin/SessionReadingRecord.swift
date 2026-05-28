//
//  SessionReadingRecord.swift
//  smartfin
//

import Foundation

struct SessionReadingRecord: Codable, Identifiable, Equatable {
    var id: UUID
    let ensembleType: String
    let temperature: Double?
    let waterStatus: String
    let imuMatrix: [Double]?
    let imuSamples: [[Double]]?
    let timestamp: Date
    let finElapsedTimeDeciseconds: UInt32

    init(
        id: UUID = UUID(),
        ensembleType: String,
        temperature: Double?,
        waterStatus: String,
        imuMatrix: [Double]?,
        imuSamples: [[Double]]?,
        timestamp: Date,
        finElapsedTimeDeciseconds: UInt32
    ) {
        self.id = id
        self.ensembleType = ensembleType
        self.temperature = temperature
        self.waterStatus = waterStatus
        self.imuMatrix = imuMatrix
        self.imuSamples = imuSamples
        self.timestamp = timestamp
        self.finElapsedTimeDeciseconds = finElapsedTimeDeciseconds
    }
}

extension SessionReadingRecord {
    func toEnsembleReading(sessionId: UUID) -> EnsembleReading {
        var imuData: Data?
        if let imuSamples,
           let encoded = try? JSONEncoder().encode(imuSamples) {
            imuData = encoded
        }

        return EnsembleReading(
            ensembleClientId: id,
            id: sessionId,
            serverId: nil,
            ensembleType: ensembleType,
            temperature: temperature ?? 0,
            waterStatus: waterStatus,
            geoCoordinates: nil,
            imuData: imuData,
            timestamp: timestamp
        )
    }
}

final class SessionReadingStore {
    static let shared = SessionReadingStore()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    private var directoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SmartFinSessionReadings", isDirectory: true)
    }

    func fileURL(for sessionId: UUID) -> URL {
        directoryURL.appendingPathComponent("\(sessionId.uuidString).json")
    }

    func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func resetSession(sessionId: UUID) throws {
        try ensureDirectoryExists()
        let url = fileURL(for: sessionId)
        let empty = try encoder.encode([SessionReadingRecord]())
        try empty.write(to: url, options: .atomic)
    }

    func loadReadings(sessionId: UUID) -> [SessionReadingRecord] {
        let url = fileURL(for: sessionId)
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([SessionReadingRecord].self, from: data)) ?? []
    }

    func saveReadings(_ readings: [SessionReadingRecord], sessionId: UUID) throws {
        try ensureDirectoryExists()
        let data = try encoder.encode(readings)
        try data.write(to: fileURL(for: sessionId), options: .atomic)
    }

    func append(_ record: SessionReadingRecord, sessionId: UUID) throws {
        var readings = loadReadings(sessionId: sessionId)
        readings.append(record)
        try saveReadings(readings, sessionId: sessionId)
    }
}
