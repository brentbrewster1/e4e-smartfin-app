//
//  BluetoothListView.swift
//  smartfin
//
//  Created by Brent Brewster on 1/28/26.
//
// NOTE: This scans for bluetooth devices & ONLY includes ones that include "Smartfin" or "SmartFin" in the name

import SwiftUI
import CoreBluetooth

struct BluetoothListView: View {
    @ObservedObject var bleManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode // To close the menu

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Smartfin Devices Found")) {
                    // If we're running against the mock in Simulator, show the
                    // simulated peripheral list and allow connecting to them.
                    if let mock = bleManager as? MockBluetoothManager {
                        if mock.simulatedPeripherals.isEmpty {
                            Text("Scanning...")
                                .foregroundColor(.gray)
                                .italic()
                        } else {
                            ForEach(mock.simulatedPeripherals) { peripheral in
                                Button(action: {
                                    mock.connectToSimulatedPeripheral(peripheral.id)
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack {
                                        Text(peripheral.name)
                                            .fontWeight(.bold)
                                        Spacer()
                                        Text("Connect")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } else {
                        // Real device path — show discovered CBPeripherals
                        if bleManager.discoveredPeripherals.isEmpty {
                            Text("Scanning...")
                                .foregroundColor(.gray)
                                .italic()
                        } else {
                            ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                                Button(action: {
                                    // Connect when tapped
                                    bleManager.connect(to: peripheral)
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    HStack {
                                        Text(peripheral.name ?? "Unknown Device")
                                            .fontWeight(.bold)
                                        Spacer()
                                        Text("Connect")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Connect Device")
            .onAppear {
                if bleManager is MockBluetoothManager {
                    return
                }
                bleManager.startScanning()
            }
            .onDisappear {
                if bleManager is MockBluetoothManager {
                    return
                }
                if !bleManager.isConnected {
                    bleManager.stopSessionScan()
                }
            }
        }
    }
}
