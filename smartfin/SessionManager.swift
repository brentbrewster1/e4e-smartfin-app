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
    // MARK: - Published Properties
    @Published var isSessionActive = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentTemperature: Double = 67.0
    @Published var samplesCollected: Int = 0
    @Published var averageTemperature: Double = 0.0
    @Published var gpsEnabled = false
    @Published var savedSessions: [SessionData] = []
    
    // MARK: - Private Properties
    private var sessionStartTime: Date?
    private var timer: Timer?
    private var lastTemperatureF: Double = 67.0

    // Collected readings now include ensemble metadata (IMU, water status, etc.)
    private struct CollectedReading: Codable {
        let ensembleType: String
        let temperature: Double
        let waterStatus: String
        let imuMatrix: [Double]?
        let imuSamples: [[Double]]?
        let timestamp: Date
        let finElapsedTimeDeciseconds: UInt32?
    }

    private var collectedReadings: [CollectedReading] = []
    private var currentDeviceName: String = "SmartFin"
    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocationCoordinate2D?
    private var bluetoothManager: BluetoothManager?
    private var cancellables = Set<AnyCancellable>()
    
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
        cancellables.removeAll()
        bluetoothManager = manager

        manager.decodedTelemetry
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ensembles in
                self?.handleDecodedEnsembles(ensembles)
            }
            .store(in: &cancellables)
    }

    private static func waterLabel(_ raw: UInt8) -> String {
        switch raw {
        case 0: return "dry"
        case 1: return "in-water"
        default: return "raw_\(raw)"
        }
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
    
    func startSession() {
        guard !isSessionActive else { return }
        
        isSessionActive = true
        sessionStartTime = Date()
        elapsedTime = 0
        samplesCollected = 0
        collectedReadings = []
        lastTemperatureF = 67.0

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
        timer?.invalidate()
        timer = nil
        
        // Stop location tracking
        locationManager?.stopUpdatingLocation()

        // Calculate average temperature
        let temps = collectedReadings.compactMap { reading -> Double? in
            guard reading.ensembleType == "01" else { return nil }
            return reading.temperature
        }
        if !temps.isEmpty {
            averageTemperature = temps.reduce(0, +) / Double(temps.count)
        }
    }
    
    func reset() {
        elapsedTime = 0
        currentTemperature = 67.0
        samplesCollected = 0
        averageTemperature = 0.0
        collectedReadings = []
        lastTemperatureF = 67.0
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
        let tempF = 67.0 + tempVariation
        appendCollectedReading(
            ensembleType: "01",
            temperature: tempF,
            waterStatus: "dry",
            imuMatrix: nil,
            imuSamples: nil,
            finElapsedTimeDeciseconds: nil
        )
    }

    private func appendCollectedReading(
        ensembleType: String,
        temperature: Double,
        waterStatus: String,
        imuMatrix: [Double]?,
        imuSamples: [[Double]]?,
        finElapsedTimeDeciseconds: UInt32?
    ) {
        currentTemperature = temperature

        let reading = CollectedReading(
            ensembleType: ensembleType,
            temperature: temperature,
            waterStatus: waterStatus,
            imuMatrix: imuMatrix,
            imuSamples: imuSamples,
            timestamp: Date(),
            finElapsedTimeDeciseconds: finElapsedTimeDeciseconds
        )
        collectedReadings.append(reading)
        samplesCollected = collectedReadings.count
    }

    // Handle incoming ensembles (simplified for frontend)
    private func handleDecodedEnsembles(_ ensembles: [DecodedFinEnsemble]) {
        guard isSessionActive else { return }

        for ensemble in ensembles {
            switch ensemble {
            case .temperatureWater(let finDs, let celsius, let waterRaw):
                let tempF = celsius * 9.0 / 5.0 + 32.0
                lastTemperatureF = tempF
                appendCollectedReading(
                    ensembleType: "01",
                    temperature: tempF,
                    waterStatus: Self.waterLabel(waterRaw),
                    imuMatrix: nil,
                    imuSamples: nil,
                    finElapsedTimeDeciseconds: finDs
                )
            case .highRateIMU(let finDs, let imu9):
                appendCollectedReading(
                    ensembleType: "0C",
                    temperature: lastTemperatureF,
                    waterStatus: "n/a",
                    imuMatrix: nil,
                    imuSamples: [imu9],
                    finElapsedTimeDeciseconds: finDs
                )
            }
        }
    }
    
    // MARK: - Session Saving
    func saveSession() async {
        guard let startTime = sessionStartTime else { return }

        let sessionId = UUID()
        let session = SessionData(
            id: sessionId,
            date: startTime,
            duration: elapsedTime,
            samplesCollected: samplesCollected,
            averageTemp: averageTemperature,
            deviceName: currentDeviceName
        )

        persistSessionReadings(sessionId: sessionId, readings: collectedReadings)

        // Save locally
        savedSessions.append(session)
        saveToDisk()

        // Upload to server
        await uploadToServer(session: session)
    }

    private func persistSessionReadings(sessionId: UUID, readings: [CollectedReading]) {
        guard let dir = applicationSupportSessionsDirectory() else { return }
        let url = dir.appendingPathComponent("\(sessionId.uuidString).json", isDirectory: false)
        do {
            let data = try JSONEncoder().encode(readings)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Session readings save failed: \(error.localizedDescription)")
        }
    }

    private func applicationSupportSessionsDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("SmartFinSessionReadings", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            print("Could not create sessions directory: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Server Upload
    private func uploadToServer(session: SessionData) async {
        // Prepare ensemble readings for upload
        var readings: [EnsembleReading] = []
        for reading in collectedReadings {
            // Encode imu data as JSON string if present
            var imuDataString: String? = nil
            if let matrix = reading.imuMatrix {
                if let d = try? JSONEncoder().encode(matrix), let s = String(data: d, encoding: .utf8) {
                    imuDataString = s
                }
            } else if let samples = reading.imuSamples {
                if let d = try? JSONEncoder().encode(samples), let s = String(data: d, encoding: .utf8) {
                    imuDataString = s
                }
            }

            let er = EnsembleReading(
                id: UUID().uuidString,
                ensembleType: reading.ensembleType,
                temperature: reading.temperature,
                waterStatus: reading.waterStatus,
                geoCoordinates: currentLocation.map { "\($0.latitude),\($0.longitude)" },
                imuData: imuDataString,
                timestamp: reading.timestamp
            )
            readings.append(er)
        }

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
    private func saveToDisk() {
        if let encoded = try? JSONEncoder().encode(savedSessions) {
            UserDefaults.standard.set(encoded, forKey: "savedSessions")
        }
    }
    
    private func loadSavedSessions() {
        if let data = UserDefaults.standard.data(forKey: "savedSessions"),
           let decoded = try? JSONDecoder().decode([SessionData].self, from: data) {
            savedSessions = decoded
        }
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
    let id: String
    let ensembleType: String
    let temperature: Double
    let waterStatus: String
    let geoCoordinates: String?
    let imuData: String?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ensembleType = "ensemble_type"
        case temperature
        case waterStatus = "water_status"
        case geoCoordinates = "geo_coordinates"
        case imuData = "imu_data"
        case timestamp
    }
}

struct UploadPayload: Codable {
    let deviceID: String
    let value: [EnsembleReading]
    let timestamp: Date
}
