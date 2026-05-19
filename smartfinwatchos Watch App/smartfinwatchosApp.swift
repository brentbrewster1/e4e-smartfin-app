//
//  smartfinwatchosApp.swift
//  smartfinwatchos Watch App
//
//  Created by Brent Brewster on 2/9/26.
//  This file defines the main entry point for the watchOS app, managing the app lifecycle and initializing key components.
//

import SwiftUI

@main
struct smartfinwatchos_Watch_AppApp: App {
    @StateObject private var sessionManager: SessionManager
    @StateObject private var watchSyncManager: WatchSyncDataManager

    init() {
        let manager = SessionManager()
        _sessionManager = StateObject(wrappedValue: manager)
        _watchSyncManager = StateObject(wrappedValue: WatchSyncDataManager(sessionManager: manager))
    }

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
            ContentView(
                bluetoothManager: bluetoothManager,
                sessionManager: sessionManager,
                watchSyncManager: watchSyncManager
            )
        }
    }
}
