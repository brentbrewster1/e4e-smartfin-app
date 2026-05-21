import Foundation
import CoreBluetooth
import Combine

enum SmartFinDecodeError: Error, Equatable {
    case packetTooShort
    case incompleteEnsembleHeader
    case incompleteTemperatureRecord
    case incompleteIMURecord
    case outOfBounds
}

enum DecodedFinEnsemble: Equatable {
    case temperatureWater(finElapsedDs: UInt32, celsius: Double, waterRaw: UInt8, tempRaw: Int16)
    case highRateIMU(finElapsedDs: UInt32, imu9: [Double])
}

enum SmartFinTelemetryDecoder {
    private static let transportHeaderSize = 6
    private static let ensembleHeaderSize = 3
    private static let ensTemp: UInt8 = 0x01
    private static let ensHighRateIMU: UInt8 = 0x0C

    static func decodePacket(_ data: Data) -> [DecodedFinEnsemble] {
        guard data.count >= transportHeaderSize else { return [] }

        let payloadLen = readUInt16LE(data, offset: 4)
        let payloadEnd = min(data.count, transportHeaderSize + Int(payloadLen))
        let payload = data.subdata(in: transportHeaderSize..<payloadEnd)

        var results: [DecodedFinEnsemble] = []
        var offset = 0

        while offset + ensembleHeaderSize <= payload.count {
            guard let header = try? decodeEnsembleHeader(payload, offset: offset) else { break }

            let recordSize: Int?
            switch header.ensembleType {
            case ensTemp:
                recordSize = ensembleHeaderSize + 3
            case ensHighRateIMU:
                recordSize = ensembleHeaderSize + 18
            default:
                recordSize = nil
            }

            guard let rs = recordSize else { break }
            if offset + rs > payload.count { break }

            switch header.ensembleType {
            case ensTemp:
                if let reading = try? decodeTemperatureWater(payload, offset: offset) {
                    results.append(.temperatureWater(
                        finElapsedDs: header.elapsedTimeDeciseconds,
                        celsius: reading.temperatureCelsius,
                        waterRaw: reading.waterStatusRaw,
                        tempRaw: reading.temperatureRaw
                    ))
                }
            case ensHighRateIMU:
                if let reading = try? decodeHighRateIMU(payload, offset: offset) {
                    results.append(.highRateIMU(finElapsedDs: header.elapsedTimeDeciseconds, imu9: reading.imu9))
                }
            default:
                break
            }

            offset += rs
        }

        return results
    }

    private struct EnsembleHeader {
        let ensembleType: UInt8
        let elapsedTimeDeciseconds: UInt32
    }

    private static func decodeEnsembleHeader(_ data: Data, offset: Int) throws -> EnsembleHeader {
        guard offset + ensembleHeaderSize <= data.count else {
            throw SmartFinDecodeError.incompleteEnsembleHeader
        }

        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let headerWord = b0 | (b1 << 8) | (b2 << 16)

        let ensembleType = UInt8(headerWord & 0x0F)
        let elapsedTimeDs = (headerWord >> 4) & 0xFFFFF

        return EnsembleHeader(ensembleType: ensembleType, elapsedTimeDeciseconds: elapsedTimeDs)
    }

    private struct TemperatureWaterReading {
        let temperatureRaw: Int16
        let temperatureCelsius: Double
        let waterStatusRaw: UInt8
    }

    private static func decodeTemperatureWater(_ data: Data, offset: Int) throws -> TemperatureWaterReading {
        let valueOffset = offset + ensembleHeaderSize
        guard valueOffset + 3 <= data.count else {
            throw SmartFinDecodeError.incompleteTemperatureRecord
        }

        let raw = try readInt16LE(data, offset: valueOffset)
        let water = data[valueOffset + 2]
        let tempC = Double(raw) / 128.0

        return TemperatureWaterReading(temperatureRaw: raw, temperatureCelsius: tempC, waterStatusRaw: water)
    }

    /// Lines for the in-app live data log (raw hex + decoded fields).
    static func liveLogLines(for data: Data, decoded: [DecodedFinEnsemble], maxHexBytes: Int = 40) -> [String] {
        var lines: [String] = []
        let shown = data.prefix(maxHexBytes)
        let hex = shown.map { String(format: "%02x", $0) }.joined(separator: " ")
        let suffix = data.count > maxHexBytes ? " +\(data.count - maxHexBytes)b" : ""
        lines.append("rx \(data.count)b: \(hex)\(suffix)")

        if data.count >= 6 {
            let ver = data[0]
            let typ = data[1]
            let seq = readUInt16LE(data, offset: 2)
            let payLen = readUInt16LE(data, offset: 4)
            lines.append("  hdr v=\(ver) typ=\(typ) seq=\(seq) payLen=\(payLen)")
        }

        if decoded.isEmpty {
            lines.append("  decoded: (none)")
            return lines
        }

        for item in decoded {
            switch item {
            case .temperatureWater(let finDs, let celsius, let waterRaw, let tempRaw):
                let tempF = celsius * 9.0 / 5.0 + 32.0
                let water: String
                switch waterRaw {
                case 0: water = "dry"
                case 1: water = "in-water"
                default: water = "raw_\(waterRaw)"
                }
                var line = String(
                    format: "  01 temp raw=%d -> %.2fC %.0fF %@ finDs=%u",
                    tempRaw, celsius, tempF, water, finDs
                )
                if tempF < -50 || tempF > 150 || celsius < -10 || celsius > 60 {
                    line += " (!)"
                }
                lines.append(line)
            case .highRateIMU(let finDs, let imu9):
                let preview = imu9.prefix(3).map { String(format: "%.3f", $0) }.joined(separator: ",")
                lines.append("  0C imu [\(preview),…] finDs=\(finDs)")
            }
        }
        return lines
    }

    private struct HighRateIMUReading {
        let imu9: [Double]
    }

    private static func decodeHighRateIMU(_ data: Data, offset: Int) throws -> HighRateIMUReading {
        let valueOffset = offset + ensembleHeaderSize
        guard valueOffset + 18 <= data.count else {
            throw SmartFinDecodeError.incompleteIMURecord
        }

        let ax = try readInt16LE(data, offset: valueOffset + 0)
        let ay = try readInt16LE(data, offset: valueOffset + 2)
        let az = try readInt16LE(data, offset: valueOffset + 4)
        let gx = try readInt16LE(data, offset: valueOffset + 6)
        let gy = try readInt16LE(data, offset: valueOffset + 8)
        let gz = try readInt16LE(data, offset: valueOffset + 10)
        let mx = try readInt16LE(data, offset: valueOffset + 12)
        let my = try readInt16LE(data, offset: valueOffset + 14)
        let mz = try readInt16LE(data, offset: valueOffset + 16)

        let imu9: [Double] = [
            Double(ax) / 16384.0, Double(ay) / 16384.0, Double(az) / 16384.0,
            Double(gx) / 128.0, Double(gy) / 128.0, Double(gz) / 128.0,
            Double(mx) / 8.0, Double(my) / 8.0, Double(mz) / 8.0
        ]

        return HighRateIMUReading(imu9: imu9)
    }

    private static func readInt16LE(_ data: Data, offset: Int) throws -> Int16 {
        guard offset + 2 <= data.count else { throw SmartFinDecodeError.outOfBounds }
        let lo = UInt16(data[offset])
        let hi = UInt16(data[offset + 1])
        return Int16(bitPattern: lo | (hi << 8))
    }

    private static func readUInt16LE(_ data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let lo = UInt16(data[offset])
        let hi = UInt16(data[offset + 1])
        return lo | (hi << 8)
    }
}

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

    private var pendingStartScan = false

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
            pendingStartScan = true
            connectionStatus = "Waiting for Bluetooth..."
            return
        }

        pendingStartScan = false
        discoveredPeripherals.removeAll()
        connectionStatus = "Searching for SmartFin..."
        appendToDataLog("Started scanning for SmartFin devices")

        // Scan for all peripherals (or filter by service UUID if we have it)
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        centralManager?.stopScan()
    }

    /// Stop scanning and clear the discovery list (e.g. user cancelled fin selection).
    func endDeviceSearch() {
        pendingStartScan = false
        stopScanning()
        discoveredPeripherals.removeAll()
        if !isConnected {
            connectionStatus = "Bluetooth ready"
        }
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
            if case .temperatureWater(_, let celsius, let waterRaw, _) = e {
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
            let logLines = SmartFinTelemetryDecoder.liveLogLines(for: copy, decoded: decoded)
            DispatchQueue.main.async {
                guard let self = self else { return }
                for line in logLines {
                    self.appendToDataLog(line)
                }
                if !decoded.isEmpty {
                    self.applyDecodedEnsembles(decoded)
                    self.decodedTelemetry.send(decoded)
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
            if pendingStartScan {
                pendingStartScan = false
                startScanning()
            }
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
        guard Self.peripheralLooksLikeSmartFin(peripheral, advertisementData: advertisementData) else { return }
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            let label = peripheral.name
                ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
                ?? "SmartFin"
            appendToDataLog("Discovered: \(label) (RSSI: \(RSSI))")
        }
    }

    /// Advertised / local name must contain `"smartfin"` (case-insensitive).
    private static func peripheralLooksLikeSmartFin(_ peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        let local = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let candidates = [peripheral.name, local].compactMap { $0 }
        guard !candidates.isEmpty else { return false }
        return candidates.contains { $0.range(of: "smartfin", options: .caseInsensitive) != nil }
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
