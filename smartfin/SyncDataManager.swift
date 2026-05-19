//
//  SyncDataManager.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 5/12/26.
//

import Foundation
import WatchConnectivity
import Combine

final class SyncDataManager: NSObject, ObservableObject {
	@Published private(set) var activationState: WCSessionActivationState = .notActivated
	@Published private(set) var lastReceivedBatchId: UUID?
	@Published private(set) var lastSyncError: String?
	@Published private(set) var lastDebugBatchId: UUID?

	private enum PayloadKey {
		static let batchData = "watchTransferBatchData"
		static let batchId = "batchId"
		static let createdAt = "createdAt"
		static let schemaVersion = "schemaVersion"
		static let sourcePlatform = "sourcePlatform"
		static let watchInstallId = "watchInstallId"
		static let sessions = "sessions"
	}

	private let sessionManager: SessionManager
	private let decoder: JSONDecoder

	init(sessionManager: SessionManager = SessionManager()) {
		self.sessionManager = sessionManager
		self.decoder = JSONDecoder()
		super.init()
		activateSessionIfAvailable()
	}

	private func activateSessionIfAvailable() {
		guard WCSession.isSupported() else {
			lastSyncError = "WatchConnectivity is not supported on this device"
			return
		}

		let session = WCSession.default
		session.delegate = self
		session.activate()
	}

	private func receive(batch: WatchTransferBatch) {
		DispatchQueue.main.async {
			self.lastReceivedBatchId = batch.batchId
			self.lastSyncError = nil
			self.sessionManager.mergeTransferredBatch(batch)

			Task {
				await self.sessionManager.uploadPendingSessions()
				await self.sessionManager.uploadPendingEnsembles()
			}
		}
	}

	private func decodeBatch(from userInfo: [String: Any]) throws -> WatchTransferBatch {
		if let batchData = userInfo[PayloadKey.batchData] as? Data {
			return try decoder.decode(WatchTransferBatch.self, from: batchData)
		}

		guard JSONSerialization.isValidJSONObject(userInfo) else {
			throw SyncDataManagerError.invalidPayload
		}

		let data = try JSONSerialization.data(withJSONObject: userInfo, options: [])
		return try decoder.decode(WatchTransferBatch.self, from: data)
	}

	private func handleIncoming(userInfo: [String: Any]) {
		do {
			let batch = try decodeBatch(from: userInfo)
			receive(batch: batch)
		} catch {
			DispatchQueue.main.async {
				self.lastSyncError = error.localizedDescription
			}
		}
	}

	#if DEBUG
	func sendDebugMockBatchToServer(sessionCount: Int = 1, ensemblesPerSession: Int = 5) {
		let clampedSessionCount = max(1, sessionCount)
		let clampedEnsembleCount = max(1, ensemblesPerSession)

		let baseDate = Date()
		let watchInstallId = UUID()
		let batchId = UUID()

		let sessions = (0..<clampedSessionCount).map { sessionIndex in
			let sessionId = UUID()
			let sessionStart = baseDate.addingTimeInterval(TimeInterval(-(sessionIndex * 120)))
			let sessionEnd = sessionStart.addingTimeInterval(TimeInterval(clampedEnsembleCount * 2))

			let ensembles = (0..<clampedEnsembleCount).map { ensembleIndex in
				WatchTransferEnsemble(
					ensembleClientId: UUID(),
					clientSessionId: sessionId,
					ensembleType: "01",
					temperature: 67.0 + Double(ensembleIndex),
					waterStatus: ensembleIndex.isMultiple(of: 3) ? "in-water" : "dry",
					geoCoordinates: nil,
					imuDataBase64: nil,
					timestamp: sessionStart.addingTimeInterval(TimeInterval(ensembleIndex * 2))
				)
			}

			let avgTemp = ensembles.map(\ .temperature).reduce(0, +) / Double(ensembles.count)

			return WatchTransferSession(
				clientSessionId: sessionId,
				deviceName: "Simulator SmartFin",
				startedAt: sessionStart,
				endedAt: sessionEnd,
				duration: sessionEnd.timeIntervalSince(sessionStart),
				samplesCollected: ensembles.count,
				averageTemp: avgTemp,
				transferStatus: .pending,
				ensembles: ensembles
			)
		}

		let batch = WatchTransferBatch(
			schemaVersion: 1,
			sourcePlatform: "debug-simulator",
			watchInstallId: watchInstallId,
			batchId: batchId,
			createdAt: baseDate,
			sessions: sessions
		)

		DispatchQueue.main.async {
			self.lastDebugBatchId = batchId
		}

		receive(batch: batch)
	}
	#endif
}

extension SyncDataManager: WCSessionDelegate {
	func session(
		_ session: WCSession,
		activationDidCompleteWith activationState: WCSessionActivationState,
		error: (any Error)?
	) {
		DispatchQueue.main.async {
			self.activationState = activationState
			self.lastSyncError = error?.localizedDescription
		}
	}

	func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
		handleIncoming(userInfo: userInfo)
	}

	func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
		handleIncoming(userInfo: applicationContext)
	}

	func sessionDidBecomeInactive(_ session: WCSession) {
		DispatchQueue.main.async {
			self.activationState = session.activationState
		}
	}

	func sessionDidDeactivate(_ session: WCSession) {
		session.activate()
	}
}

private enum SyncDataManagerError: LocalizedError {
	case invalidPayload

	var errorDescription: String? {
		switch self {
		case .invalidPayload:
			return "Received an invalid watch transfer payload"
		}
	}
}
