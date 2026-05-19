//
//  smartfinApp.swift
//  smartfin
//

import SwiftUI

private final class AppBluetoothLaunchBox: ObservableObject {
    let manager = BluetoothManager()
}

@main
struct smartfinApp: App {
    @StateObject private var bluetoothLaunch = AppBluetoothLaunchBox()

    var body: some Scene {
        WindowGroup {
            ContentView(bluetoothManager: bluetoothLaunch.manager)
        }
    }
}
