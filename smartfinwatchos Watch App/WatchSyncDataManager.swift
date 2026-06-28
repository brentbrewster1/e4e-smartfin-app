//
//  WatchSyncDataManager.swift
//  smartfinwatchos Watch App
//
//  This file manages the synchronization of data from the watch to the phone using WatchConnectivity. It handles session activation, data transfer, and error reporting.
//

import Foundation
import WatchConnectivity
import Combine

final class WatchSyncDataManager: NSObject, ObservableObject {
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var lastSentBatchId: UUID?
    @Published private(set) var lastSyncError: String?

    private enum StorageKey {
        static let watchInstallId = "watchInstallId"
    }

    private enum PayloadKey {
        static let batchData = "watchTransferBatchData"
        static let batchId = "batchId"
        static let createdAt = "createdAt"
        static let schemaVersion = "schemaVersion"
        static let sourcePlatform = "sourcePlatform"
    }

    private let sessionManager: SessionManager
    private let encoder = JSONEncoder()
    private let watchInstallId: UUID

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager

        if let existing = UserDefaults.standard.string(forKey: StorageKey.watchInstallId),
           let uuid = UUID(uuidString: existing) {
            self.watchInstallId = uuid
        } else {
            let generated = UUID()
            self.watchInstallId = generated
            UserDefaults.standard.set(generated.uuidString, forKey: StorageKey.watchInstallId)
        }

        super.init()
        activateSessionIfAvailable()
    }

    func flushPendingToPhone() {
        guard WCSession.isSupported() else {
            lastSyncError = "WatchConnectivity is not supported on this watch"
            return
        }

        guard activationState == .activated else {
            return
        }

        guard let batch = sessionManager.makeTransferBatch(watchInstallId: watchInstallId) else {
            return
        }

        do {
            let data = try encoder.encode(batch)
            let payload: [String: Any] = [
                PayloadKey.batchData: data,
                PayloadKey.batchId: batch.batchId.uuidString,
                PayloadKey.createdAt: batch.createdAt.timeIntervalSince1970,
                PayloadKey.schemaVersion: batch.schemaVersion,
                PayloadKey.sourcePlatform: batch.sourcePlatform
            ]

            WCSession.default.transferUserInfo(payload)
            lastSentBatchId = batch.batchId
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func activateSessionIfAvailable() {
        guard WCSession.isSupported() else {
            lastSyncError = "WatchConnectivity is not supported on this watch"
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
}

extension WatchSyncDataManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        DispatchQueue.main.async {
            self.activationState = activationState
            self.isReachable = session.isReachable
            self.lastSyncError = error?.localizedDescription
            if activationState == .activated {
                self.flushPendingToPhone()
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable {
                self.flushPendingToPhone()
            }
        }
    }
}