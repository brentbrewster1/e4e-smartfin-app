import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Searching for SmartFin..."
    @Published var currentTemperature: Double = 67.0
    @Published var waterStatus: String = "unknown"
    @Published var batteryLevel: Int = 100
    @Published var dataLog: [String] = []

    let decodedTelemetry = PassthroughSubject<[DecodedFinEnsemble], Never>()

    // MARK: - Core Bluetooth
    var centralManager: CBCentralManager?
    private var telemetryCharacteristic: CBCharacteristic?
    // Keep a strong reference to the peripheral we're attempting to connect to
    private var pendingPeripheral: CBPeripheral?

    private let telemetryDecodeQueue = DispatchQueue(label: "com.smartfin.telemetry.decode", qos: .userInitiated)

    // MARK: - Service & Characteristic UUIDs
    static let telemetryUUID = CBUUID(string: "DEEDDB00-166E-407C-8158-7B9693AD2685")
    static let controlUUID = CBUUID(string: "C39513E6-631E-439A-9B3B-AFFA0635B3D1")

    // Update these with actual SmartFin UUIDs (leave as placeholder for previews)
    private let smartFinServiceUUIDString = "SF-SERVICE-UUID"

    // Parsed CBUUIDs (nil when placeholder/invalid)
    private lazy var smartFinServiceUUID: CBUUID? = {
        return Self.cbuuid(from: smartFinServiceUUIDString)
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

    // MARK: - Scanning
    func startScanning() {
        guard centralManager?.state == .poweredOn else {
            connectionStatus = "Bluetooth is not available"
            return
        }

        discoveredPeripherals.removeAll()
        connectionStatus = "Searching for SmartFin..."
        appendToDataLog("Started scanning for SmartFin devices")

        // Scan for all peripherals (or filter by service UUID if we have it)
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        centralManager?.stopScan()
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
        stopScanning()
        connectionStatus = "Connecting to \(peripheral.name ?? "SmartFin")..."
        appendToDataLog("Connecting to \(peripheral.name ?? "SmartFin")")
        // Retain the peripheral while connection is in progress and ensure we
        // receive peripheral delegate callbacks by setting the delegate now.
        pendingPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard let device = connectedDevice else { return }
        centralManager?.cancelPeripheralConnection(device)
        isConnected = false
        connectedDevice = nil
        telemetryCharacteristic = nil
        connectionStatus = "Disconnected"
        appendToDataLog("Disconnected from device")
    }

    // MARK: - Data Reading
    private func setupNotifications(for peripheral: CBPeripheral) {
        // Enable notifications for temperature characteristic
        guard let characteristic = telemetryCharacteristic else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    // Data -> hex string helper for logging
    private func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func waterStatusString(_ raw: UInt8) -> String {
        switch raw {
        case 0: return "dry"
        case 1: return "in-water"
        default: return "raw_\(raw)"
        }
    }

    private func applyDecodedEnsembles(_ ensembles: [DecodedFinEnsemble]) {
        for e in ensembles {
            if case .temperatureWater(_, let celsius, let waterRaw) = e {
                let tempF = celsius * 9.0 / 5.0 + 32.0
                currentTemperature = tempF
                waterStatus = Self.waterStatusString(waterRaw)
            }
        }
    }

    private func processTelemetryData(_ data: Data) {
        let copy = Data(data)
        telemetryDecodeQueue.async { [weak self] in
            let decoded = SmartFinTelemetryDecoder.decodePacket(copy)
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !decoded.isEmpty {
                    self.applyDecodedEnsembles(decoded)
                    self.decodedTelemetry.send(decoded)
                } else if copy.count >= 6 {
                    self.appendToDataLog("Tele: 0 ensembles (\(copy.count) B) \(self.hexString(from: Data(copy.prefix(16))))")
                }
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth ready"
            startScanning()
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

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Filter for SmartFin devices
        if let name = peripheral.name, name.contains("SmartFin") || name.contains("Smartfin") {
            // Avoid duplicates
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredPeripherals.append(peripheral)
                appendToDataLog("Discovered: \(name) (RSSI: \(RSSI))")
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        // Clear pending and promote to connectedDevice
        pendingPeripheral = nil
        connectedDevice = peripheral
        telemetryCharacteristic = nil
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
        telemetryCharacteristic = nil

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
        guard let services = peripheral.services else { return }

        for service in services {
            // If we have a configured temperature characteristic UUID, request only that one.
            // Otherwise request all characteristics so we can inspect them.
            peripheral.discoverCharacteristics([Self.telemetryUUID, Self.controlUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            appendToDataLog("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == Self.telemetryUUID {
                telemetryCharacteristic = characteristic
                setupNotifications(for: peripheral)
                peripheral.readValue(for: characteristic)
                appendToDataLog("Subscribed to SmartFin telemetry")
                return
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.telemetryUUID else { return }
        guard error == nil, let data = characteristic.value, !data.isEmpty else {
            if let error = error {
                appendToDataLog("Telemetry read error: \(error.localizedDescription)")
            }
            return
        }

        processTelemetryData(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Notification state update error: \(error.localizedDescription)")
        } else {
            print("Notifications enabled for: \(characteristic.uuid)")
        }
    }
}
