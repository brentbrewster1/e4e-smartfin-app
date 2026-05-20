//
//  SessionManager.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/25/26.
//


import Foundation
import Combine
import CoreLocation

// MARK: - Session Manager
class SessionManager: NSObject, ObservableObject {
    private var serverManager: ServerManager
    // MARK: - Published Properties
    @Published var isSessionActive = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentTemperature: Double = 67.0
    @Published var samplesCollected: Int = 0
    @Published var averageTemperature: Double = 0.0
    @Published var gpsEnabled = false
    @Published var savedSessions: [SessionData] = []
    @Published var savedEnsembles: [EnsembleReading] = []
    
    // MARK: - Private Properties
    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocationCoordinate2D?
    private var bluetoothManager: BluetoothManager?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    // Data related to current session
    private var sessionStartTime: Date?
    private var sessionEndTime: Date?
    private var ensemblesInCurrentSession: [EnsembleReading] = []
    private var clientSessionId: UUID = UUID()
    private var currentDeviceName: String = "SmartFin"
    
    // Using BluetoothNetworkManager for uploads (server-side session upload is handled by the BluetoothNetworkManager)
    
    // MARK: - Computed Properties
    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Initialization
    override init() {
        self.serverManager = ServerManager.shared
        super.init()
        // Avoid requesting location services during SwiftUI previews
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            setupLocationManager()
        } else {
            gpsEnabled = false
        }

        loadSavedSessions()
    }

    // MARK: - Bluetooth Binding
    /// Bind a BluetoothManager instance so sessions can record real ensemble-driven samples.
    func bindBluetoothManager(_ manager: BluetoothManager) {
        bluetoothManager = manager

        // Subscribe to temperature + waterStatus from the Bluetooth manager.
        // Simpler: we don't assume Ensemble IDs here — frontend only needs temp + water state.
        manager.$currentTemperature
            .combineLatest(manager.$waterStatus)
            .sink { [weak self] temp, water in
                guard let self = self else { return }
                self.handleEnsemble(ensembleType: "01",
                                    temperature: temp,
                                    waterStatus: water,
                                    imuMatrix: nil,
                                    imuSamples: nil,
                                    timestamp: Date())
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Location Setup
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
    }
    
    // MARK: - Session Control
    func prepareSession(deviceName: String) {
        self.currentDeviceName = deviceName
    }
    
    // WARNING: This clears all previous session and ensemble data not saved to disk or sent to the server
    func startSession() {
        guard !isSessionActive else { return }
        
        isSessionActive = true
        sessionStartTime = Date()
        elapsedTime = 0
        samplesCollected = 0
        ensemblesInCurrentSession = []
        clientSessionId = UUID()
        
        // Start location tracking
        locationManager?.startUpdatingLocation()
        gpsEnabled = true
        
        // Start timer for elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
        
        // If a BluetoothManager is bound, live BLE data will drive samples; otherwise use simulation
        if bluetoothManager == nil {
            startDataCollection()
        }
    }
    
    func endSession() {
        guard isSessionActive else { return }
        
        isSessionActive = false
        sessionEndTime = Date()
        timer?.invalidate()
        timer = nil
        
        // Stop location tracking
        locationManager?.stopUpdatingLocation()
        
        saveSessionLocal()
//        print("SESSION COUNT:", savedSessions.count)
//        print("SESSION IDS:", savedSessions.map { $0.id })
    }
    
    func reset() {
        elapsedTime = 0
        currentTemperature = 67.0
        samplesCollected = 0
        averageTemperature = 0.0
        ensemblesInCurrentSession = []
        gpsEnabled = false
    }
    
    // MARK: - Data Collection
    private func updateElapsedTime() {
        guard let startTime = sessionStartTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }
    
    private func startDataCollection() {
        // Simulate receiving data from SmartFin every 2 seconds
        // In production, this would be triggered by BLE characteristic updates
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isSessionActive else {
                timer.invalidate()
                return
            }
            
            self.collectSample()
        }
    }
    
    private func collectSample() {
        // Simulate temperature variation (replace with actual BLE data)
        let tempVariation = Double.random(in: -2...2)
        currentTemperature = 67.0 + tempVariation

        let ensemble = EnsembleReading(
            id: clientSessionId,
            serverId: nil,
            ensembleType: "01",
            temperature: currentTemperature,
            waterStatus: "dry",
            geoCoordinates: nil,
            imuData: nil,
            timestamp: Date()
        )
        ensemblesInCurrentSession.append(ensemble)
        samplesCollected = ensemblesInCurrentSession.count
        saveEnsembleLocal()
    }

    // Handle incoming ensembles (simplified for frontend)
    private func handleEnsemble(ensembleType: String, temperature: Double, waterStatus: String, imuMatrix: [Double]?, imuSamples: [[Double]]?, timestamp: Date) {
        currentTemperature = temperature
        
        // Encode imu data as JSON string if present
        var imuDataString: String? = nil
        
        if let matrix = imuMatrix {
            if let d = try? JSONEncoder().encode(matrix), let s = String(data: d, encoding: .utf8) {
                imuDataString = s
            }
        } else if let samples = imuSamples {
            if let d = try? JSONEncoder().encode(samples), let s = String(data: d, encoding: .utf8) {
                imuDataString = s
            }
        }
        
        let ensemble = EnsembleReading(
            id: clientSessionId,
            serverId: nil,
            ensembleType: ensembleType,
            temperature: temperature,
            waterStatus: waterStatus,
            geoCoordinates: currentLocation.map { "\($0.latitude),\($0.longitude)" },
            imuData: imuDataString?.data(using: .utf8),
            timestamp: timestamp
        )
        
        ensemblesInCurrentSession.append(ensemble)
        samplesCollected = ensemblesInCurrentSession.count
        saveEnsembleLocal()
    }
    
    // MARK: - Session Saving
    func saveSessionLocal() {
        guard let startTime = sessionStartTime else { return }
        guard let endTime = sessionEndTime else { return }
        
        // Calculate average temperature
        if !ensemblesInCurrentSession.isEmpty {
            let temps = ensemblesInCurrentSession.map { $0.temperature }
            averageTemperature = temps.reduce(0, +) / Double(temps.count)
        }
        
        let session = SessionData(
            id: clientSessionId,
            serverId: nil,
            startedAt: startTime,
            endedAt: endTime,
            duration: elapsedTime, // calculated throughout session
            samplesCollected: samplesCollected, // calculated on each ensemble append
            averageTemp: averageTemperature,
            deviceName: currentDeviceName
        )
        
        // Save locally
        savedSessions.append(session)
        saveSessionsToDisk()
    }
    
    // MARK: - Ensemble Saving
    func saveEnsembleLocal() {
        // edge case -- could potentially add duplicates, such as on crash
        for ensemble in ensemblesInCurrentSession {
            savedEnsembles.append(ensemble)
        }
        
        saveEnsemblesToDisk()
    }
    
    
    // MARK: - Server Upload
    private func uploadToServer(readings: [EnsembleReading]) async {
        // BluetoothNetworkManager expects a string 'value' payload. Encode readings to JSON string and send.
        do {
            let data = try JSONEncoder().encode(readings)
            if let jsonString = String(data: data, encoding: .utf8) {
                BluetoothNetworkManager.shared.uploadBluetoothData(value: jsonString, deviceID: currentDeviceName)
                print("Session queued for upload via BluetoothNetworkManager")
            } else {
                print("Failed to convert readings JSON to string")
            }
        } catch {
            print("Failed to encode readings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Persistence
    private func saveSessionsToDisk() {
        if let encoded = try? JSONEncoder().encode(savedSessions) {
            UserDefaults.standard.set(encoded, forKey: "savedSessions")
        }
    }
    
    private func saveEnsemblesToDisk() {
        if let encoded = try? JSONEncoder().encode(savedEnsembles) {
            UserDefaults.standard.set(encoded, forKey: "savedEnsembles")
        }
    }
    
    private func loadSavedSessions() {
        if let data = UserDefaults.standard.data(forKey: "savedSessions"),
           let decoded = try? JSONDecoder().decode([SessionData].self, from: data) {
            savedSessions = decoded
        }
    }
    
    private func clearSavedData() {
        UserDefaults.standard.removeObject(forKey: "savedSessions")
        UserDefaults.standard.removeObject(forKey: "savedEnsembles")
    }
    
    // MARK: - Syncing between local and server
    // checks ensembles list and uploads any stragglers
    func uploadPendingEnsembles() async {
        for ensembleIndex in savedEnsembles.indices {
            // Skip already-uploaded ensembles
            guard savedEnsembles[ensembleIndex].serverId == nil else {
                continue
            }

            let ensemble = savedEnsembles[ensembleIndex]

            // Find corresponding session
            guard let session = savedSessions.first(where: {
                $0.id == ensemble.id
            }) else {
                print("Missing local session for ensemble \(ensemble.id)")
                continue
            }
            
            // Session must already exist on server
            guard let serverSessionId = session.serverId else {
                continue
            }
            
            do {
                // Upload ensemble
                let serverId = try await serverManager.postEnsemble(ensemble, serverSessionId: serverSessionId)

                // Update local ensemble with server ID
                savedEnsembles[ensembleIndex].serverId = serverId

            } catch {
                print("Failed to upload ensemble \(ensemble.id): \(error)")
            }
        }

        saveEnsemblesToDisk()
    }
    
    // checks full local session list and uploads any stragglers
    func uploadPendingSessions() async {
        for index in savedSessions.indices {
            // Skip already-uploaded sessions
            guard savedSessions[index].serverId == nil else {
                continue
            }

            do {
                // Upload current local session
                let serverID = try await serverManager.postSession(savedSessions[index])
                // Update local session with ID returned by server
                savedSessions[index].serverId = serverID

            } catch {
                print("Failed to upload session \(savedSessions[index].id): \(error)")
            }
        }

        saveSessionsToDisk()
    }
    
    // for uploading individual sessions
    func uploadSessionToServer(_ session: SessionData) async -> SessionData? {
        do {
            let sessionID = try await serverManager.postSession(session)
            
            var updatedSession = session
            updatedSession.serverId = sessionID

            return updatedSession
        } catch {
            print(error)
            return nil
        }
    }
    
    func mergeSessions(_ remoteSessions: [SessionData]) {
        var merged = savedSessions
        
        for remote in remoteSessions {
            let existingIndex = merged.firstIndex { local in
                // Match synced sessions - match based on serverID, but if local is nil then match on clientID
                if let localServerId = local.serverId,
                   let remoteServerId = remote.serverId {
                    return localServerId == remoteServerId
                }

                // Match local UUIDs
                return local.id == remote.id
            }
            if let index = existingIndex {
                merged[index] = remote
            } else {
                // not stored locally! safe to just add to list
                merged.append(remote)
            }
        }
        savedSessions = merged
    }
    
    func mergeEnsembles(_ remoteEnsembles: [EnsembleReading]) {
        var merged = savedEnsembles

        for remote in remoteEnsembles {

            let existingIndex = merged.firstIndex { local in
                // Prefer matching server IDs when available
                if let localServerId = local.serverId,
                   let remoteServerId = remote.serverId {
                    return localServerId == remoteServerId
                }
                // Otherwise match local UUIDs
                return local.id == remote.id
            }

            if let index = existingIndex {
                merged[index] = remote
            } else {
                // not stored locally! safe to just add to list
                merged.append(remote)
            }
        }

        savedEnsembles = merged
    }
    
    // Get remote sessions, save locally if not already. Upload any session not yet in the server.
    func syncSessions() async {
        do {
            let remoteSessions = try await serverManager.getSessions()
            mergeSessions(remoteSessions)

            await uploadPendingSessions()

            saveSessionsToDisk()

        } catch {
            print(error)
        }
    }
    
    func syncEnsembles() async {
        do {
            let remoteEnsembles = try await serverManager.getEnsembles()
            mergeEnsembles(remoteEnsembles)

            await uploadPendingEnsembles()
            saveEnsemblesToDisk()
        } catch {
            print(error)
        }
    }
    
    func syncData() async {
        await uploadPendingSessions()
        await uploadPendingEnsembles()
    }
}

// MARK: - CLLocationManagerDelegate
extension SessionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        gpsEnabled = true
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        gpsEnabled = false
    }
}

// MARK: - Data Models for Server Upload
struct EnsembleReading: Codable {
    let id: UUID
    var serverId: Int? // nil if not uploaded to server (or haven't received a response)
    let ensembleType: String
    let temperature: Double
    let waterStatus: String
    let geoCoordinates: String?
    let imuData: Data?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id = "client_session_id"
        case serverId = "id"
        case ensembleType = "ensemble_type"
        case temperature
        case waterStatus = "water_status"
        case geoCoordinates = "geo_coordinates"
        case imuData = "imu_data"
        case timestamp
    }
}

struct ServerEnsemble: Codable {
    let id: Int
    let session_id: String
    let ensemble_type: String
    let temperature: Double?
    let water_status: String?
    let gps: String?
    let imu: String?
    let timestamp: Date?

    func toEnsembleReading() -> EnsembleReading {
        EnsembleReading(
            id: UUID(), // generate local UUID since server id is Int
            serverId: id,
            ensembleType: ensemble_type,
            temperature: temperature ?? 0.0,
            waterStatus: water_status ?? "Unknown",
            geoCoordinates: gps,
            imuData: imu?.data(using: .utf8),
            timestamp: timestamp ?? Date()
        )
    }
}
