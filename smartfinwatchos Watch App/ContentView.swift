//
//  ContentView.swift
//  smartfinwatchos Watch App
//
//  Created by Brent Brewster on 2/9/26.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject var bluetoothManager: BluetoothManager
    @State private var showSessionFlow = false

    init(bluetoothManager: BluetoothManager = BluetoothManager()) {
        _bluetoothManager = StateObject(wrappedValue: bluetoothManager)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if bluetoothManager.isConnected {
                    // Once connected, show the session flow
                    SessionFlowView()
                        .environmentObject(bluetoothManager)
                } else {
                    // Show connection interface
                    ConnectionView(bluetoothManager: bluetoothManager)
                }
            }
        }
    }
}

// MARK: - Connection View
struct ConnectionView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack {
            if bluetoothManager.discoveredPeripherals.isEmpty {
                // Searching state
                SearchingView(status: bluetoothManager.connectionStatus)
            } else if bluetoothManager.discoveredPeripherals.count == 1 {
                // Single device - simple button
                SingleDeviceView(
                    device: bluetoothManager.discoveredPeripherals.first!,
                    onConnect: { device in
                        bluetoothManager.connect(to: device)
                    }
                )
            } else {
                // Multiple devices - show list
                MultipleDevicesView(
                    devices: bluetoothManager.discoveredPeripherals,
                    onConnect: { device in
                        bluetoothManager.connect(to: device)
                    }
                )
            }
        }
        .onAppear {
            if bluetoothManager.centralManager?.state == .poweredOn {
                bluetoothManager.startScanning()
            }
        }
    }
}

// MARK: - Searching View
struct SearchingView: View {
    let status: String
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text(status)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Single Device View
struct SingleDeviceView: View {
    let device: CBPeripheral
    let onConnect: (CBPeripheral) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "water.waves.and.arrow.down")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            VStack(spacing: 4) {
                Text("Connect to")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                
                Text(device.name ?? "SmartFin")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: { onConnect(device) }) {
                Text("Connect")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}

// MARK: - Multiple Devices View
struct MultipleDevicesView: View {
    let devices: [CBPeripheral]
    let onConnect: (CBPeripheral) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Select SmartFin")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top)
            
            List(devices, id: \.identifier) { device in
                Button(action: { onConnect(device) }) {
                    HStack {
                        Image(systemName: "water.waves")
                            .foregroundColor(.blue)
                        
                        Text(device.name ?? "Unknown Fin")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    ContentView(bluetoothManager: MockBluetoothManager())
}
