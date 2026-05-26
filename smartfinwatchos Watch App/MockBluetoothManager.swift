//
//  MockBluetoothManager.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//
import Foundation
import CoreBluetooth
import Combine

/// A lightweight mock of `BluetoothManager` used for SwiftUI previews and the
/// watch simulator. It subclasses the real `BluetoothManager` and overrides
/// behavior to avoid CoreBluetooth interactions while emitting synthetic data.
class MockBluetoothManager: BluetoothManager {
    private var timer: Timer?
    private var sampleIndex = 0

    struct SimPeripheral: Identifiable {
        let id: UUID
        let name: String
    }

    @Published var simulatedPeripherals: [SimPeripheral] = []

    override init() {
        super.init()

        // Configure a friendly mock state for previews/simulator
        self.connectionStatus = "Watch Mock Ready"
        self.isConnected = false
        self.currentTemperature = 72.0
        self.batteryLevel = 95
        self.dataLog = ["Watch mock active"]

        // Populate a few simulated peripherals so the connection UI can list them
        simulatedPeripherals = [
            SimPeripheral(id: UUID(), name: "Watch Mock SmartFin #1"),
            SimPeripheral(id: UUID(), name: "Watch Mock SmartFin #2")
        ]

        startMocking()
    }

    private func startMocking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sampleIndex += 1
            let temp = 58.0 + Double(Int.random(in: 0...200)) / 10.0
            self.currentTemperature = temp
            self.waterStatus = (self.sampleIndex % 6 == 0) ? "in-water" : "dry"
            let msg = String(format: "[Watch Mock] sample %03d — temp=%.1f, water=%@", self.sampleIndex, self.currentTemperature, self.waterStatus)
            DispatchQueue.main.async {
                self.dataLog.append(msg)
                if self.dataLog.count > 500 { self.dataLog.removeFirst(self.dataLog.count - 500) }
            }
        }
    }

    @MainActor deinit {
        timer?.invalidate()
        timer = nil
    }

    override func startScanning() {
        // No-op — we already have simulated peripherals
        self.connectionStatus = "Simulated scanning"
    }

    func connectToSimulatedPeripheral(_ id: UUID) {
        guard let p = simulatedPeripherals.first(where: { $0.id == id }) else { return }
        self.isConnected = true
        self.connectionStatus = "Connected (Mock) to \(p.name)"
        DispatchQueue.main.async {
            self.dataLog.append("[Watch Mock] Connected to \(p.name)")
        }
    }

    override func connect(to peripheral: CBPeripheral) {
        // If someone calls connect with a real CBPeripheral, just mark connected
        self.isConnected = true
        self.connectionStatus = "Connected (Mock)"
    }

    override func disconnect() {
        self.isConnected = false
        self.connectionStatus = "Disconnected (Mock)"
    }
}
