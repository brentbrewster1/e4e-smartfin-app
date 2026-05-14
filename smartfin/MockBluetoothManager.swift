import Foundation
#if os(watchOS)
import CoreBluetooth
#endif

/// Simulator / preview mock of `BluetoothManager` with synthetic telemetry (`DecodedFinEnsemble`).
///
/// iPhone: used from `BluetoothListView` / previews when `targetEnvironment(simulator)`.
/// Watch: used from `smartfinwatchosApp` when `targetEnvironment(simulator)`.
class MockBluetoothManager: BluetoothManager {
    private var timer: Timer?
    private var sampleIndex = 0

    // Simple simulated peripheral model so the connection UI can list devices.
    struct SimPeripheral: Identifiable {
        let id: UUID
        let name: String
    }

    @Published var simulatedPeripherals: [SimPeripheral] = []

    override init() {
        super.init()

#if os(watchOS)
        connectionStatus = "Watch Mock Ready"
        isConnected = false
        currentTemperature = 72.0
        batteryLevel = 95
        dataLog = ["Watch mock active"]
        simulatedPeripherals = [
            SimPeripheral(id: UUID(), name: "Watch Mock SmartFin #1"),
            SimPeripheral(id: UUID(), name: "Watch Mock SmartFin #2")
        ]
#else
        // Avoid real CoreBluetooth in the iOS Simulator mock.
        centralManager = nil
        connectionStatus = "Simulator (Mock)"
        isConnected = false
        dataLog = ["Simulator mock active", "Emitting synthetic samples..."]
        simulatedPeripherals = [
            SimPeripheral(id: UUID(), name: "Mock SmartFin #1"),
            SimPeripheral(id: UUID(), name: "Mock SmartFin #2"),
            SimPeripheral(id: UUID(), name: "Mock SmartFin #3")
        ]
#endif
        startMocking()
    }

    private func startMocking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sampleIndex += 1

            let tempF = 58.0 + Double(Int.random(in: 0...200)) / 10.0
            let celsius = (tempF - 32.0) * 5.0 / 9.0
            let waterRaw: UInt8 = (self.sampleIndex % 6 == 0) ? 1 : 0
            let sample = DecodedFinEnsemble.temperatureWater(
                finElapsedDs: UInt32(self.sampleIndex % 0xFFFFF),
                celsius: celsius,
                waterRaw: waterRaw
            )

            DispatchQueue.main.async {
                self.currentTemperature = tempF
                self.waterStatus = waterRaw == 1 ? "in-water" : "dry"
                self.decodedTelemetry.send([sample])
                let msg: String
#if os(watchOS)
                msg = String(format: "[Watch Mock] sample %03d — temp=%.1f, water=%@", self.sampleIndex, tempF, self.waterStatus)
#else
                msg = String(format: "Mock sample %03d — temp=%.1f, water=%@", self.sampleIndex, tempF, self.waterStatus)
#endif
                self.dataLog.append(msg)
                if self.dataLog.count > 500 {
                    self.dataLog.removeFirst(self.dataLog.count - 500)
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    func connectToSimulatedPeripheral(_ id: UUID) {
        guard let p = simulatedPeripherals.first(where: { $0.id == id }) else { return }
        isConnected = true
#if os(watchOS)
        connectionStatus = "Connected (Mock) to \(p.name)"
        DispatchQueue.main.async {
            self.dataLog.append("[Watch Mock] Connected to \(p.name)")
        }
#else
        connectionStatus = "Connected (Mock) to \(p.name)"
        DispatchQueue.main.async {
            self.dataLog.append("[Mock] Connected to \(p.name)")
        }
#endif
    }

#if os(watchOS)
    override func startScanning() {
        connectionStatus = "Simulated scanning"
    }

    override func connect(to peripheral: CBPeripheral) {
        isConnected = true
        connectionStatus = "Connected (Mock)"
    }

    override func disconnect() {
        isConnected = false
        connectionStatus = "Disconnected (Mock)"
    }
#endif
}
