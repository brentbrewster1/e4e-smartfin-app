//
//  ContentView.swift
//  smartfin
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    init(bluetoothManager: BluetoothManager) {
        _bluetoothManager = ObservedObject(wrappedValue: bluetoothManager)
    }

    var body: some View {
        NavigationStack {
            SessionFlowView(bluetoothManager: bluetoothManager)
        }
    }
}

#Preview {
    ContentView(bluetoothManager: BluetoothManager())
}
