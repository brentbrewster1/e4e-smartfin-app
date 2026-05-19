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
    @Published var connectionStatus: String = "Searching for SmartFin..."
    @Published var currentTemperature: Double = 67.0
    @Published var waterStatus: String = "unknown"
    @Published var batteryLevel: Int = 100
    @Published var dataLog: [String] = []
    
    // MARK: - Core Bluetooth
    var centralManager: CBCentralManager?
    private var smartFinCharacteristic: CBCharacteristic?
    // Keep a strong reference to the peripheral we're attempting to connect to
    private var pendingPeripheral: CBPeripheral?
    
    // MARK: - Service & Characteristic UUIDs
    // Update these with actual SmartFin UUIDs (leave as placeholder for previews)
    private let smartFinServiceUUIDString = "SF-SERVICE-UUID"
    private let smartFinCharacteristicUUIDString = "SF-CHARACTERISTIC-UUID"

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
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
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
        smartFinCharacteristic = nil
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

        for service in services {
            appendToDataLog("Service: \(service.uuid.uuidString)")
            // If we have a configured temperature characteristic UUID, request only that one.
            // Otherwise request all characteristics so we can inspect them.
            let charsToDiscover = smartFinCharacteristicUUID != nil ? [smartFinCharacteristicUUID!] : nil
            peripheral.discoverCharacteristics(charsToDiscover, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            appendToDataLog("Characteristic discovery failed for \(service.uuid.uuidString): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }
        appendToDataLog("Found \(characteristics.count) characteristic(s) for \(service.uuid.uuidString)")

        // Preserve an already selected stream characteristic.
        if smartFinCharacteristic != nil {
            return
        }

        for characteristic in characteristics {
            if let tempUUID = smartFinCharacteristicUUID {
                if characteristic.uuid == tempUUID {
                    smartFinCharacteristic = characteristic
                    appendToDataLog("Selected configured characteristic: \(characteristic.uuid.uuidString)")
                    setupNotifications(for: peripheral)
                    peripheral.readValue(for: characteristic)
                    break
                }
            } else {
                // No configured UUID — prefer characteristics that can stream or be read.
                let props = characteristic.properties
                let isCandidate = props.contains(.notify) || props.contains(.indicate) || props.contains(.read)
                guard isCandidate else { continue }

                smartFinCharacteristic = characteristic
                appendToDataLog("Auto-selected characteristic: \(characteristic.uuid.uuidString) (no configured UUID)")
                setupNotifications(for: peripheral)
                peripheral.readValue(for: characteristic)
                break
            }
        }

        if smartFinCharacteristic == nil {
            appendToDataLog("No suitable characteristic selected for service \(service.uuid.uuidString)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            appendToDataLog("Value update error for \(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return
        }

        // Only attempt parsing if this matches our temperature characteristic (or if we don't have one configured)
        if smartFinCharacteristic == nil || characteristic.uuid == smartFinCharacteristic?.uuid {
            if let data = characteristic.value {
                // Log raw payload for easier debugging
                appendToDataLog("Raw payload: \(hexString(from: data))")

                // Simplified parsing for frontend:
                // - If payload >= 5 bytes and first byte looks like ensemble ID, parse temp from bytes 1..4
                // - Otherwise if payload >= 4, parse temp from bytes 0..3 (legacy float)
                // - Do not attempt IMU parsing here (unknown format). Leave imuMatrix/imuSamples empty.
                simpleParsePayload(data)
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
                
    // MARK: - Simplified payload parsing for frontend
    private func simpleParsePayload(_ data: Data) {
        // Very simple parsing for frontend only:
        // - If payload >=5 bytes: assume [id:1][temp:4] and optional water byte at index 5
        // - Else if payload >=4: assume legacy float at start
        // - Do not attempt to extract IMU data here
        let count = data.count
        if count >= 5 {
            // temp bytes are 1..4
            let tempData = data.subdata(in: 1..<5)
            let u32 = UInt32(littleEndian: tempData.withUnsafeBytes { $0.load(as: UInt32.self) })
            let f = Float(bitPattern: u32)
            currentTemperature = Double(f)

            if count >= 6 {
                let w = data[5]
                waterStatus = (w == 0) ? "dry" : "in-water"
            }

            appendToDataLog("Parsed payload: temp=\(String(format: "%.2f", currentTemperature)), water=\(waterStatus)")
            return
        }

        if count >= 4 {
            let u32 = UInt32(littleEndian: data.withUnsafeBytes { $0.load(as: UInt32.self) })
            let f = Float(bitPattern: u32)
            currentTemperature = Double(f)
            appendToDataLog(String(format: "Parsed legacy temp: %.2f°F", currentTemperature))
            return
        }

        appendToDataLog("Payload too short to parse: \(hexString(from: data))")
    }

    // Data -> hex string helper for logging
    private func hexString(from data: Data) -> String {
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
