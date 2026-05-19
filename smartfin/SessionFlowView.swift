//
//  SessionFlowView.swift
//  smartfin
//

import SwiftUI
import CoreBluetooth
#if os(watchOS)
import WatchKit
#endif

struct SessionFlowView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @StateObject var sessionManager: SessionManager
    @State private var sessionState: SessionState = .ready

    init(bluetoothManager: BluetoothManager, sessionManager: SessionManager = SessionManager()) {
        _bluetoothManager = ObservedObject(wrappedValue: bluetoothManager)
        _sessionManager = StateObject(wrappedValue: sessionManager)
    }

    var body: some View {
        ZStack {
            switch sessionState {
            case .ready:
                ReadyView(onStart: {
                    if bluetoothManager.isConnected {
                        sessionManager.prepareSession(deviceName: bluetoothManager.connectedDevice?.name ?? "SmartFin")
                        sessionState = .active
                        sessionManager.startSession()
                        enableWaterLockIfWatch()
                    } else {
                        sessionState = .selectFin
                    }
                })

            case .selectFin:
                VStack(spacing: 8) {
                    Button(action: {
                        bluetoothManager.endDeviceSearch()
                        sessionState = .ready
                    }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    ConnectionView(bluetoothManager: bluetoothManager)
                }
                .padding(.horizontal, 4)

            case .active:
                ActiveSessionView(
                    sessionManager: sessionManager,
                    bluetoothManager: bluetoothManager,
                    onEnd: {
                        sessionState = .complete
                        sessionManager.endSession()
                    }
                )

            case .complete:
                SessionCompleteView(
                    sessionManager: sessionManager,
                    onSave: {
                        Task {
                            await sessionManager.saveSession()
                            sessionState = .history
                        }
                    }
                )

            case .history:
                SessionHistoryView(
                    sessions: sessionManager.savedSessions,
                    onNewSession: {
                        bluetoothManager.disconnect()
                        bluetoothManager.endDeviceSearch()
                        sessionState = .ready
                        sessionManager.reset()
                    }
                )
            }
        }
        .onAppear {
            sessionManager.bindBluetoothManager(bluetoothManager)
        }
        .onChange(of: bluetoothManager.isConnected) { connected in
            guard connected else { return }
            if sessionState == .selectFin {
                sessionManager.prepareSession(deviceName: bluetoothManager.connectedDevice?.name ?? "SmartFin")
                sessionState = .active
                sessionManager.startSession()
                enableWaterLockIfWatch()
            }
        }
    }

    private func enableWaterLockIfWatch() {
        #if os(watchOS)
        WKInterfaceDevice.current().enableWaterLock()
        #endif
    }
}
