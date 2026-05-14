//
//  ContentView.swift
//  smartfinwatchos Watch App
//
//  Created by Brent Brewster on 2/9/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    init(bluetoothManager: BluetoothManager) {
        _bluetoothManager = ObservedObject(wrappedValue: bluetoothManager)
    }

    var body: some View {
        NavigationView {
            SessionFlowView(bluetoothManager: bluetoothManager)
        }
    }
}

#Preview {
    ContentView(bluetoothManager: BluetoothManager())
}
