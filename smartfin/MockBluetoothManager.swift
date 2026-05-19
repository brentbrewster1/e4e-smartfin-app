import Foundation
import Combine

/// A very small simulator-only mock that subclasses `BluetoothManager` and
/// publishes synthetic readings so the UI can be exercised in the Simulator.
/// `BluetoothManager` on device builds because we instantiate the mock only
/// when `targetEnvironment(simulator)` is true.
class MockBluetoothManager: BluetoothManager {
    private var timer: Timer?
    private var sampleIndex = 0
    
    // Simple simulated peripheral model used only by the mock so the UI can
    // display a list of connectable devices in the Simulator.
    struct SimPeripheral: Identifiable {
        let id: UUID
        let name: String
    }

    @Published var simulatedPeripherals: [SimPeripheral] = []

    override init() {
        super.init()

        // Ensure we don't try to use a real central manager from the mock.
        // BluetoothManager may have created one during init; clear it so we
        // won't perform real scanning when running in the Simulator.
        self.centralManager = nil
        self.connectionStatus = "Simulator (Mock)"
        self.isConnected = true

        // Seed a few log entries so the UI isn't empty immediately
        self.dataLog = ["Simulator mock active", "Emitting synthetic samples..."]

        // Start emitting fake data periodically
        startMocking()

        // Seed a few simulated peripherals so the BluetoothListView can show
        // connectable mock devices in the Simulator.
        simulatedPeripherals = [
            SimPeripheral(id: UUID(), name: "Mock SmartFin #1"),
            SimPeripheral(id: UUID(), name: "Mock SmartFin #2"),
            SimPeripheral(id: UUID(), name: "Mock SmartFin #3")
        ]
    }

    private func startMocking() {
        // Emit a synthetic sample every 1 second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sampleIndex += 1

            // Generate a temperature between 58.0 and 78.0
            let temp = 58.0 + Double(Int.random(in: 0...200)) / 10.0
            self.currentTemperature = temp
            self.waterStatus = (self.sampleIndex % 6 == 0) ? "in-water" : "dry"

            let msg = String(format: "Mock sample %03d — temp=%.1f, water=%@", self.sampleIndex, self.currentTemperature, self.waterStatus)
            // Append to the published dataLog while keeping it bounded
            DispatchQueue.main.async {
                self.dataLog.append(msg)
                if self.dataLog.count > 500 {
                    self.dataLog.removeFirst(self.dataLog.count - 500)
                }
            }
        }
    }

    @MainActor deinit {
        timer?.invalidate()
        timer = nil
    }

    // Allow the UI to "connect" to a simulated peripheral in the mock.
    func connectToSimulatedPeripheral(_ id: UUID) {
        guard let p = simulatedPeripherals.first(where: { $0.id == id }) else { return }
        self.isConnected = true
        self.connectionStatus = "Connected (Mock) to \(p.name)"
        DispatchQueue.main.async {
            self.dataLog.append("[Mock] Connected to \(p.name)")
        }
    }
}
