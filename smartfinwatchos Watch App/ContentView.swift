//
//  ContentView.swift
//  smartfinwatchos Watch App
//
//  Created by Brent Brewster on 2/9/26.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    // Initialize your shared BluetoothManager here
    @StateObject var bluetoothManager = BluetoothManager()
    
    var body: some View {
        VStack {
            // 1. If we are already connected, show the success state
            if bluetoothManager.connectionStatus.contains("Connected") {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    Text(bluetoothManager.connectionStatus)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
            } else {
                // 2. If not connected, handle the discovery logic
                handleDiscoveryState()
            }
        }
        .onAppear {
            // Ensure scanning starts when the view loads
            // (Your manager starts scanning automatically in init, but good to be safe)
             if bluetoothManager.centralManager.state == .poweredOn {
                 bluetoothManager.centralManager.scanForPeripherals(withServices: nil, options: nil)
             }
        }
    }
    
    // This function handles the "Switch" logic you asked for
    @ViewBuilder
    func handleDiscoveryState() -> some View {
        if bluetoothManager.discoveredPeripherals.isEmpty {
            // CASE 0: No devices found yet
            VStack(spacing: 8) {
                ProgressView()
                    .tint(.blue)
                Text(bluetoothManager.connectionStatus) // "Searching..."
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
        } else if bluetoothManager.discoveredPeripherals.count == 1 {
            // CASE 1: EXACTLY ONE DEVICE (The "Simple Button")
            if let device = bluetoothManager.discoveredPeripherals.first {
                Button(action: {
                    bluetoothManager.connect(to: device)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "wave.3.left.circle.fill")
                            .font(.title2)
                        Text("Connect to")
                            .font(.caption2)
                            .textCase(.uppercase)
                        Text(device.name ?? "Smartfin")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            
        } else {
            // CASE 2: MULTIPLE DEVICES (The "Dropdown/List")
            VStack {
                Text("Select Smartfin")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                List(bluetoothManager.discoveredPeripherals, id: \.identifier) { device in
                    Button(action: {
                        bluetoothManager.connect(to: device)
                    }) {
                        HStack {
                            Text(device.name ?? "Unknown Fin")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listStyle(.elliptical) // Optimizes list look for circular watch faces
            }
        }
    }
}
