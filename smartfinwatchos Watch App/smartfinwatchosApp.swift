//
//  smartfinwatchosApp.swift
//  smartfinwatchos Watch App
//
//  Created by Brent Brewster on 2/9/26.
//

import SwiftUI

@main
struct smartfinwatchos_Watch_AppApp: App {
    // Create a Bluetooth manager appropriate for the environment: use the
    // simulator mock when running in the watch simulator, otherwise use the
    // real manager on device.
    var bluetoothManager: BluetoothManager = {
#if targetEnvironment(simulator)
        return MockBluetoothManager()
#else
        return BluetoothManager()
#endif
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(bluetoothManager: bluetoothManager)
        }
    }
}
