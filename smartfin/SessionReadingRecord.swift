//
//  SessionReadingRecord.swift
//  smartfin
//

import Foundation

/// One decoded row persisted with a session (matches JSON written by `SessionManager`).
struct SessionReadingRecord: Codable, Hashable {
    let ensembleType: String
    let temperature: Double
    let waterStatus: String
    let imuMatrix: [Double]?
    let imuSamples: [[Double]]?
    let timestamp: Date
    let finElapsedTimeDeciseconds: UInt32?
}

enum SessionReadingsFileStore {
    private static let folderName = "SmartFinSessionReadings"

    private static func applicationSupportURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    /// Ensures `…/Application Support/SmartFinSessionReadings` exists (for writes).
    static func ensureSessionsDirectory() -> URL? {
        guard let appSupport = applicationSupportURL() else { return nil }
        let dir = appSupport.appendingPathComponent(folderName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return nil
        }
    }

    static func readingsFileURL(sessionId: UUID) -> URL? {
        guard let dir = ensureSessionsDirectory() else { return nil }
        return dir.appendingPathComponent("\(sessionId.uuidString).json", isDirectory: false)
    }

    enum LoadResult {
        case noFile
        case decodeFailed(String)
        case success([SessionReadingRecord])
    }

    /// Loads persisted readings if the JSON file exists (does not create directories).
    static func loadReadings(sessionId: UUID) -> LoadResult {
        guard let appSupport = applicationSupportURL() else { return .noFile }
        let url = appSupport
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent("\(sessionId.uuidString).json", isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return .noFile }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([SessionReadingRecord].self, from: data)
            return .success(decoded)
        } catch {
            return .decodeFailed(error.localizedDescription)
        }
    }
}
