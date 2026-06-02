//  BluetoothManager.swift
//  smartfin
//
//  This file manages Bluetooth connectivity, including scanning for devices, connecting, and handling data transfer.
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Bluetooth starting..."
    @Published var currentTemperature: Double = 67.0
    @Published var waterStatus: String = "unknown"
    @Published var lastIMU9: [Double]?
    @Published var batteryLevel: Int = 100
    @Published var dataLog: [String] = []
    @Published private(set) var packetsReceived: Int = 0
    var onDecodedEnsembles: (([DecodedFinEnsemble]) -> Void)?
    
    // MARK: - Core Bluetooth
    var centralManager: CBCentralManager?
    private var smartFinCharacteristic: CBCharacteristic?
    private var telemetryPollTimer: Timer?
    private var discoveredStreamCandidates: [CBCharacteristic] = []
    private var servicesAwaitingCharacteristics = 0
    // Keep a strong reference to the peripheral we're attempting to connect to
    private var pendingPeripheral: CBPeripheral?
    @Published private(set) var isSessionScanActive = false
    private var sessionScanAutoConnect = false
    
    // MARK: - Service & Characteristic UUIDs
    private let smartFinServiceUUIDString = "SF-SERVICE-UUID"
    private let smartFinCharacteristicUUIDString = SmartFinTelemetryDecoder.telemetryCharacteristicUUID

    // Parsed CBUUIDs (nil when placeholder/invalid)
    private lazy var smartFinServiceUUID: CBUUID? = {
        return Self.cbuuid(from: smartFinServiceUUIDString)
    }()

    private lazy var smartFinCharacteristicUUID: CBUUID? = {
        return Self.cbuuid(from: smartFinCharacteristicUUIDString)
    }()

    private static func cbuuid(from string: String) -> CBUUID? {
        // Try strict 128-bit UUID first
        if let nsuuid = UUID(uuidString: string) {
            return CBUUID(nsuuid: nsuuid)
        }

        // Accept 16-bit/32-bit hex strings as valid CBUUIDs
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        let cleaned = trimmed.replacingOccurrences(of: "0x", with: "")
        if !cleaned.isEmpty && cleaned.rangeOfCharacter(from: hexSet.inverted) == nil {
            return CBUUID(string: cleaned)
        }

        // Not a valid UUID representation — return nil to avoid crash
        return nil
    }
    
    // MARK: - Initialization
    override init() {
        super.init()

        // Avoid initializing CoreBluetooth when running SwiftUI previews
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            connectionStatus = "Preview Mode"
        } else {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
    
    // MARK: - SmartFin device identification

    static func isSmartFinName(_ name: String?) -> Bool {
        guard let name, !name.isEmpty else { return false }
        return name.range(of: "smartfin", options: .caseInsensitive) != nil
    }

    func isSmartFinDevice(peripheral: CBPeripheral, advertisementData: [String: Any] = [:]) -> Bool {
        if Self.isSmartFinName(peripheral.name) { return true }
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            return Self.isSmartFinName(localName)
        }
        return false
    }

    // MARK: - Scanning

    /// Scan initiated from the home screen connect flow. Autoconnects when exactly one SmartFin is found.
    func startSessionScan(autoConnect: Bool = true) {
        beginScan(clearDiscovered: true, statusMessage: "Scanning for SmartFin...", autoConnect: autoConnect)
    }

    /// Scan initiated from the manual device picker (no autoconnect).
    func startScanning() {
        beginScan(clearDiscovered: true, statusMessage: "Searching for SmartFin...", autoConnect: false)
    }

    func stopSessionScan() {
        sessionScanAutoConnect = false
        isSessionScanActive = false
        centralManager?.stopScan()
    }

    func stopScanning() {
        stopSessionScan()
    }

    private func beginScan(clearDiscovered: Bool, statusMessage: String, autoConnect: Bool) {
        guard centralManager?.state == .poweredOn else {
            connectionStatus = "Bluetooth is not available"
            return
        }

        if clearDiscovered {
            discoveredPeripherals.removeAll()
        }
        sessionScanAutoConnect = autoConnect
        isSessionScanActive = true
        connectionStatus = statusMessage
        appendToDataLog("Started scanning for SmartFin devices")

        centralManager?.scanForPeripherals(withServices: nil, options: nil)
    }

    private func tryAutoConnectIfSingleMatch() {
        guard sessionScanAutoConnect, isSessionScanActive, !isConnected, pendingPeripheral == nil else { return }

        let matches = discoveredPeripherals
        if matches.count > 1 {
            sessionScanAutoConnect = false
            connectionStatus = "Multiple SmartFin devices found — choose one"
            return
        }

        guard matches.count == 1, let peripheral = matches.first else { return }

        sessionScanAutoConnect = false
        isSessionScanActive = false
        connect(to: peripheral)
    }

    // Simple logger to keep a running stream of status / data messages for the UI
    private func appendToDataLog(_ message: String) {
        DispatchQueue.main.async {
            self.dataLog.append(message)
            // Keep the log reasonably bounded
            if self.dataLog.count > 500 {
                self.dataLog.removeFirst(self.dataLog.count - 500)
            }
        }
    }
    
    // MARK: - Connection
    func connect(to peripheral: CBPeripheral) {
        sessionScanAutoConnect = false
        isSessionScanActive = false
        centralManager?.stopScan()
        connectionStatus = "Connecting to \(peripheral.name ?? "SmartFin")..."
        appendToDataLog("Connecting to \(peripheral.name ?? "SmartFin")")
        // Retain the peripheral while connection is in progress and ensure we
        // receive peripheral delegate callbacks by setting the delegate now.
        pendingPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        stopTelemetryPolling()
        sessionScanAutoConnect = false
        isSessionScanActive = false
        guard let device = connectedDevice else { return }
        centralManager?.cancelPeripheralConnection(device)
        isConnected = false
        connectedDevice = nil
        connectionStatus = "Disconnected"
        appendToDataLog("Disconnected from device")
    }
    
    // MARK: - Data Reading
    private func setupNotifications(for peripheral: CBPeripheral) {
        // Enable notifications for temperature characteristic
        if let characteristic = smartFinCharacteristic {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth ready — tap Connect to SmartFin"
        case .poweredOff:
            connectionStatus = "Bluetooth is off"
        case .unauthorized:
            connectionStatus = "Bluetooth not authorized"
        case .unsupported:
            connectionStatus = "Bluetooth not supported"
        default:
            connectionStatus = "Bluetooth unavailable"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard isSmartFinDevice(peripheral: peripheral, advertisementData: advertisementData) else { return }

        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            let displayName = peripheral.name
                ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
                ?? "SmartFin"
            discoveredPeripherals.append(peripheral)
            appendToDataLog("Discovered: \(displayName) (RSSI: \(RSSI))")
            tryAutoConnectIfSingleMatch()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        // Clear pending and promote to connectedDevice
        pendingPeripheral = nil
        connectedDevice = peripheral
        smartFinCharacteristic = nil
        discoveredStreamCandidates.removeAll()
        servicesAwaitingCharacteristics = 0
        connectionStatus = "Connected to \(peripheral.name ?? "SmartFin")"
        appendToDataLog("Connected to \(peripheral.name ?? "SmartFin")")
        
        // Set delegate and discover services
        peripheral.delegate = self
        // If we have a configured service UUID use it, otherwise discover all services
        peripheral.discoverServices(smartFinServiceUUID != nil ? [smartFinServiceUUID!] : nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        pendingPeripheral = nil
        connectionStatus = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        appendToDataLog(connectionStatus)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        // Clear both connected and pending references
        if connectedDevice?.identifier == peripheral.identifier {
            connectedDevice = nil
        }
        pendingPeripheral = nil
        smartFinCharacteristic = nil
        stopTelemetryPolling()
        packetsReceived = 0
        discoveredStreamCandidates.removeAll()
        servicesAwaitingCharacteristics = 0
        
        if let error = error {
            connectionStatus = "Disconnected: \(error.localizedDescription)"
        } else {
            connectionStatus = "Disconnected"
            appendToDataLog("Disconnected")
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            appendToDataLog("Service discovery failed: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }
        appendToDataLog("Discovered \(services.count) service(s)")

        discoveredStreamCandidates.removeAll()
        servicesAwaitingCharacteristics = services.count

        for service in services {
            appendToDataLog("Service: \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            appendToDataLog("Characteristic discovery failed for \(service.uuid.uuidString): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }
        appendToDataLog("Found \(characteristics.count) characteristic(s) for \(service.uuid.uuidString)")

        for characteristic in characteristics {
            let props = characteristic.properties
            let propNames = [
                props.contains(.read) ? "read" : nil,
                props.contains(.write) ? "write" : nil,
                props.contains(.notify) ? "notify" : nil,
                props.contains(.indicate) ? "indicate" : nil
            ].compactMap { $0 }.joined(separator: ",")
            appendToDataLog("  · \(characteristic.uuid.uuidString) [\(propNames)]")

            if props.contains(.notify) || props.contains(.indicate) || props.contains(.read) {
                discoveredStreamCandidates.append(characteristic)
            }
        }

        servicesAwaitingCharacteristics = max(0, servicesAwaitingCharacteristics - 1)
        if servicesAwaitingCharacteristics == 0 {
            finalizeTelemetryCharacteristicSelection(on: peripheral)
        }
    }

    private func finalizeTelemetryCharacteristicSelection(on peripheral: CBPeripheral) {
        guard smartFinCharacteristic == nil else { return }

        if let preferred = discoveredStreamCandidates.first(where: { $0.uuid == smartFinCharacteristicUUID }) {
            selectTelemetryCharacteristic(preferred, peripheral: peripheral)
            return
        }

        if let stream = discoveredStreamCandidates.first(where: {
            $0.properties.contains(.notify) || $0.properties.contains(.indicate)
        }) {
            appendToDataLog("Telemetry UUID not found; using \(stream.uuid.uuidString)")
            selectTelemetryCharacteristic(stream, peripheral: peripheral)
            return
        }

        appendToDataLog("No suitable telemetry characteristic found")
    }

    private func selectTelemetryCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        smartFinCharacteristic = characteristic
        let props = characteristic.properties
        appendToDataLog("Selected stream: \(characteristic.uuid.uuidString)")

        setupNotifications(for: peripheral)

        if props.contains(.read) {
            peripheral.readValue(for: characteristic)
            startTelemetryPolling(for: peripheral)
        } else {
            appendToDataLog("Notify-only — listening (no read/poll)")
        }
    }

    private func startTelemetryPolling(for peripheral: CBPeripheral) {
        guard let characteristic = smartFinCharacteristic,
              characteristic.properties.contains(.read) else { return }

        telemetryPollTimer?.invalidate()
        telemetryPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self,
                  let characteristic = self.smartFinCharacteristic,
                  characteristic.properties.contains(.read),
                  self.isConnected else { return }
            peripheral.readValue(for: characteristic)
        }
        appendToDataLog("Polling read every 2s")
    }

    private func stopTelemetryPolling() {
        telemetryPollTimer?.invalidate()
        telemetryPollTimer = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            let message = error.localizedDescription
            if message.localizedCaseInsensitiveContains("not permitted")
                || message.localizedCaseInsensitiveContains("not allowed") {
                stopTelemetryPolling()
                return
            }
            appendToDataLog("Value update error for \(characteristic.uuid.uuidString): \(message)")
            return
        }

        // Only attempt parsing if this matches our temperature characteristic (or if we don't have one configured)
        if smartFinCharacteristic == nil || characteristic.uuid == smartFinCharacteristic?.uuid {
            if let data = characteristic.value {
                processTelemetryData(data)
            }
            else{
                appendToDataLog("Value update contained nil data for \(characteristic.uuid.uuidString)")

            }
            
        }
        else{
            let selectedUUID = smartFinCharacteristic?.uuid.uuidString ?? String("nil")
            appendToDataLog("Ignoring value for non-selected characteristic \(characteristic.uuid.uuidString); selected=\(selectedUUID)")
        }
    }
                
    func processTelemetryData(_ data: Data) {
        DispatchQueue.main.async {
            self.packetsReceived += 1
        }

        appendToDataLog("RX \(data.count) bytes: \(hexString(from: data))")

        let ensembles = SmartFinTelemetryDecoder.decodePacket(data)

        if ensembles.isEmpty {
            appendToDataLog("Decode: no ensembles — check firmware format")
            return
        }

        DispatchQueue.main.async {
            for ensemble in ensembles {
                switch ensemble {
                case .temperatureWater(_, let celsius, let waterRaw):
                    let tempF = SmartFinTelemetryDecoder.fahrenheit(fromCelsius: celsius)
                    self.currentTemperature = tempF
                    self.waterStatus = SmartFinTelemetryDecoder.waterStatusString(from: waterRaw)
                    self.appendToDataLog(
                        String(format: "Temp %.0f°F · %@", tempF, self.waterStatus)
                    )
                case .highRateIMU(_, let imu9):
                    self.lastIMU9 = imu9
                    if imu9.count >= 3 {
                        self.appendToDataLog(
                            String(format: "IMU ax=%.2f ay=%.2f az=%.2f", imu9[0], imu9[1], imu9[2])
                        )
                    }
                }
            }
            self.onDecodedEnsembles?(ensembles)
        }
    }

    // Data -> hex string helper for logging
    func hexString(from data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            appendToDataLog("Notification state error for \(characteristic.uuid.uuidString): \(error.localizedDescription)")
        } else {
            appendToDataLog("Notifications enabled for: \(characteristic.uuid.uuidString)")
        }
    }
}
