//
//  smartfinwatchosApp.swift
//  smartfinwatchos Watch App
//
//  Created by Brent Brewster on 2/9/26.
//

import Combine
import SwiftUI

private final class WatchBluetoothLaunchBox: ObservableObject {
    let manager = BluetoothManager()
}

@main
struct smartfinwatchos_Watch_AppApp: App {
    @StateObject private var bluetoothLaunch = WatchBluetoothLaunchBox()

    var body: some Scene {
        WindowGroup {
            ContentView(bluetoothManager: bluetoothLaunch.manager)
        }
    }
}
