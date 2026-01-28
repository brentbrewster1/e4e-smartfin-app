import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var myPeripheral: CBPeripheral?
    
    // UI will watch these variables
    @Published var connectionStatus: String = "Searching..."
    @Published var discoveredPeripherals: [CBPeripheral] = [] // The list for your menu
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is On - Scanning for Smartfin...")
            // Scan for everything, we will filter in the discovery method
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            connectionStatus = "Bluetooth is Off"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // 1. FILTER: Check if the name contains "Smartfin" or Particle defaults like "Argon", "Boron"
        guard let name = peripheral.name else { return }
        
        if name.contains("Smartfin") || name.contains("Argon") || name.contains("Boron") || name.contains("Photon") {
            
            // 2. Add to our list if it's not already there
            if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                DispatchQueue.main.async {
                    self.discoveredPeripherals.append(peripheral)
                }
            }
        }
    }
    
    // Call this when the user taps a device in the menu
    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        myPeripheral = peripheral
        myPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
        connectionStatus = "Connecting to \(peripheral.name ?? "Device")..."
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionStatus = "Connected to \(peripheral.name ?? "Unknown")"
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, let dataString = String(data: data, encoding: .utf8) {
            // Send to your server
            NetworkManager.shared.uploadBluetoothData(value: dataString, deviceID: peripheral.identifier.uuidString)
        }
    }
}
