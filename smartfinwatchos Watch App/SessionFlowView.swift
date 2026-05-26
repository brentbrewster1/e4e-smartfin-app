//
//  SessionFlowView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 4/24/26.
//

import SwiftUI
import CoreBluetooth
import CoreLocation

struct SessionFlowView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var watchSyncManager: WatchSyncDataManager
    @State private var sessionState: SessionState = .ready

    init(
        bluetoothManager: BluetoothManager = BluetoothManager(),
        sessionManager: SessionManager = SessionManager(),
        watchSyncManager: WatchSyncDataManager? = nil
    ) {
        _bluetoothManager = ObservedObject(wrappedValue: bluetoothManager)
        _sessionManager = ObservedObject(wrappedValue: sessionManager)
        _watchSyncManager = ObservedObject(
            wrappedValue: watchSyncManager ?? WatchSyncDataManager(sessionManager: sessionManager)
        )
    }
    
    var body: some View {
        ZStack {
            switch sessionState {
            case .ready:
                ReadyView(onStart: {
                    sessionState = .connecting
                    sessionManager.prepareSession(deviceName: bluetoothManager.connectedDevice?.name ?? "SmartFin")
                })

            case .connecting:
                ConnectingView(
                    deviceName: bluetoothManager.connectedDevice?.name ?? "Smart Fin",
                    onCancel: {
                        sessionState = .ready
                        bluetoothManager.disconnect()
                    },
                    onConnected: {
                        sessionState = .active
                        sessionManager.startSession()
                        // Enable water lock (watchOS hardware) if available
                        #if os(watchOS)
                        WKInterfaceDevice.current().enableWaterLock()
                        #endif
                    }
                )
                .onAppear {
                    // Simulate connection or use real BLE connection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if bluetoothManager.isConnected {
                            sessionState = .active
                            sessionManager.startSession()
                        }
                    }
                }

            case .active:
                ActiveSessionView(
                    sessionManager: sessionManager,
                    watchSyncManager: watchSyncManager,
                    onEnd: {
                        sessionState = .complete
                        sessionManager.endSession()
                        watchSyncManager.flushPendingToPhone()
                    }
                )

            case .complete:
                SessionCompleteView(
                    sessionManager: sessionManager,
                    onSave: {
                        Task {
                            watchSyncManager.flushPendingToPhone()
                            sessionState = .history
                        }
                    }
                )

            case .history:
                SessionHistoryView(
                    sessions: sessionManager.savedSessions,
                    onNewSession: {
                        sessionState = .ready
                        sessionManager.reset()
                    }
                ).task {
                    watchSyncManager.flushPendingToPhone()
                }
            }
        }
        .onAppear {
            sessionManager.bindBluetoothManager(bluetoothManager)
            watchSyncManager.flushPendingToPhone()
        }
        .onChange(of: bluetoothManager.isConnected) { _, connected in
            // If we were waiting for a connection and the manager reports
            // connected, move into the active session state.
            if connected && sessionState == .connecting {
                sessionState = .active
                sessionManager.startSession()
            }

            if connected {
                watchSyncManager.flushPendingToPhone()
            }
        }
    }
}

#Preview {
    NavigationStack {
        let sessionManager = SessionManager()
        SessionFlowView(
            bluetoothManager: MockBluetoothManager(),
            sessionManager: sessionManager,
            watchSyncManager: WatchSyncDataManager(sessionManager: sessionManager)
        )
    }
}
