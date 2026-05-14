//
//  smartfinwatchosApp.swift
//  smartfinwatchos Watch App
//
//  Created by Brent Brewster on 2/9/26.
//

import Combine
import SwiftUI

/// Owns the single `BluetoothManager` for the watch app lifetime (avoids recreating on `App` body refresh).
private final class WatchBluetoothLaunchBox: ObservableObject {
    let manager: BluetoothManager

    init() {
#if targetEnvironment(simulator)
        manager = MockBluetoothManager()
#else
        manager = BluetoothManager()
#endif
    }
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
