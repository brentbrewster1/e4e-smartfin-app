//
//  BluetoothListView.swift
//  smartfin
//
//  Created by Brent Brewster on 1/28/26.
//

import SwiftUI
import CoreBluetooth

struct BluetoothListView: View {
    @ObservedObject var bleManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Smartfin Devices Found")) {
                    if bleManager.discoveredPeripherals.isEmpty {
                        Text("Scanning...")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            Button(action: {
                                bleManager.connect(to: peripheral)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                HStack {
                                    Text(peripheral.name ?? "SmartFin")
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
            .navigationTitle("Connect Device")
            .onAppear {
                if bleManager.centralManager?.state == .poweredOn {
                    bleManager.startScanning()
                }
            }
        }
    }
}
