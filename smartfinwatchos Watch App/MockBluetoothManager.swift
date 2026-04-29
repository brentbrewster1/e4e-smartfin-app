//
//  MockBluetoothManager.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//
import Foundation
import CoreBluetooth

/// A lightweight mock of `BluetoothManager` used for SwiftUI previews.
/// It subclasses the real `BluetoothManager` and overrides behavior to avoid CoreBluetooth interactions.
class MockBluetoothManager: BluetoothManager {
    override init() {
        super.init()
        // Configure a friendly mock state for previews
        self.connectionStatus = "Mock Connected"
        self.isConnected = true
        self.currentTemperature = 72.0
        self.batteryLevel = 95
        self.dataLog = ["Mock session started"]
    }

    override func startScanning() {
        // no-op for preview
    }

    override func connect(to peripheral: CBPeripheral) {
        // no-op for preview; pretend connected
        isConnected = true
    }

    override func disconnect() {
        isConnected = false
    }
}
