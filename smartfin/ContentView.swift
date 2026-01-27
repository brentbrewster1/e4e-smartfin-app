import SwiftUI
import CoreBluetooth
import Observation

struct Device: Identifiable {
    let id: UUID
    let name: String
    let p: CBPeripheral
}

@MainActor @Observable
final class BluetoothManager: NSObject { // Added colon here
    var state: CBManagerState = .unknown
    var scanning = false
    var devices: [Device] = []
    var connected: String? = nil
    
    private var central: CBCentralManager!
    
    override init() {
        super.init()
        // Initialize central after super.init
        central = CBCentralManager(delegate: self, queue: nil)
    }
    
    func scan() {
        guard state == .poweredOn else { return }
        devices.removeAll()
        connected = nil
        central.scanForPeripherals(withServices: nil)
        scanning = true
    }
    
    func stop() {
        central.stopScan()
        scanning = false
    }
    
    func connect(_ d: Device) {
        central.connect(d.p)
    }
}

extension CBManagerState {
    var title: String {
        switch self {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        @unknown default: return "New State"
        }
    }
}

// Ensure delegate methods match exactly
extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.state = central.state
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? p.name ?? "(no name)"
        let d = Device(id: p.identifier, name: name, p: p)
        if !devices.contains(where: { $0.id == d.id }) {
            devices.append(d)
        }
    }
    
    // Fixed typo: didconnect -> didConnect
    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        connected = p.name ?? p.identifier.uuidString
        stop()
    }
}

struct ContentView: View {
    @State private var ble = BluetoothManager()
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("State: \(ble.state.title)")
                Spacer()
                if let c = ble.connected {
                    Text("Connected: \(c)").foregroundStyle(.green)
                }
            }
            
            Button(ble.scanning ? "Stop" : "Scan") {
                ble.scanning ? ble.stop() : ble.scan()
            }
            .buttonStyle(.borderedProminent)
            .disabled(ble.state != .poweredOn)
            
            List(ble.devices) { d in
                HStack {
                    Text(d.name)
                    Spacer()
                    Button("Connect") { ble.connect(d) }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
}
