import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var myPeripheral: CBPeripheral?
    
    // UI will watch these variables
    @Published var connectionStatus: String = "Searching..."
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var dataLog: [String] = [] // NEW: Stores the incoming data
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is On - Scanning for Smartfin...")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            connectionStatus = "Bluetooth is Off"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else { return }
        
        if name.contains("Smartfin") || name.contains("Argon") || name.contains("Boron") || name.contains("Photon") {
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                DispatchQueue.main.async {
                    self.discoveredPeripherals.append(peripheral)
                }
            }
        }
        // ⚠️ MAKE SURE YOU DO NOT HAVE 'centralManager.connect(...)' HERE!
    }
    
    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        myPeripheral = peripheral
        myPeripheral?.delegate = self
        
        // Check if we are ALREADY connected before trying to connect again
        if peripheral.state == .connected {
            print("Device was already connected!")
            connectionStatus = "Connected to \(peripheral.name ?? "Device")"
            peripheral.discoverServices(nil)
        } else {
            connectionStatus = "Connecting to \(peripheral.name ?? "Device")..."
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ SUCCESS: didConnect fired!")
        DispatchQueue.main.async {
            self.connectionStatus = "Connected to \(peripheral.name ?? "Unknown")"
        }
        peripheral.discoverServices(nil)
    }
    
    // Catch if the connection fails entirely
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ FAILED TO CONNECT: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async {
            self.connectionStatus = "Connection Failed"
        }
    }

    // Catch if the device connects but then immediately disconnects
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("⚠️ DISCONNECTED: \(error?.localizedDescription ?? "No error provided")")
        DispatchQueue.main.async {
            self.connectionStatus = "Disconnected"
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let dataString = String(data: data, encoding: .utf8) {
            
            // Format a timestamp for the log
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let timeString = formatter.string(from: Date())
            let logEntry = "[\(timeString)] \(dataString)"
            
            // 1. Update the UI Log Window
            DispatchQueue.main.async {
                self.dataLog.append(logEntry)
                
                // Optional: Prevent memory issues by only keeping the last 100 messages
                if self.dataLog.count > 100 {
                    self.dataLog.removeFirst()
                }
            }
            
            // 2. Send to your server
            NetworkManager.shared.uploadBluetoothData(value: dataString, deviceID: peripheral.identifier.uuidString)
        }
    }
}
