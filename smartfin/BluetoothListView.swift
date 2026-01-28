//
//  BluetoothListView.swift
//  smartfin
//
//  Created by Brent Brewster on 1/28/26.
//

// NOTE: This scans for bluetooth devices & ONLY includes ones that include "Smartfin", "Argon", "Boron", or "Photon" in the name

import SwiftUI
import CoreBluetooth

struct BluetoothListView: View {
    @ObservedObject var bleManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode // To close the menu

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
            .navigationTitle("Connect Device")
        }
    }
}
