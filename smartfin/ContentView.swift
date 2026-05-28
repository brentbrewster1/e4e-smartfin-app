import SwiftUI

struct ContentView: View {
    @EnvironmentObject var syncDataManager: SyncDataManager

    // Use a lightweight simulator mock when running in Simulator so the UI can be
    // exercised without requiring real Bluetooth hardware. On a device the
    // real `BluetoothManager` will be used.
#if targetEnvironment(simulator)
    @StateObject var bleManager = MockBluetoothManager()
#else
    @StateObject var bleManager = BluetoothManager()
#endif
    @EnvironmentObject var sessionManager: SessionManager

    @State private var showBluetoothMenu = false
    @State private var showSimulatorConnectAlert = false

    private var usesRealBluetooth: Bool {
        bleManager is MockBluetoothManager == false
    }

    var body: some View {
        NavigationStack {
        VStack(spacing: 20) {

            // --- LOGO ---
            Image("SmartfinLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 250)
                .padding(.top, 40)

            // --- CONNECTION STATUS ---
            Text(bleManager.connectionStatus)
                .font(.headline)
                .foregroundColor(bleManager.isConnected ? .green : .gray)

            if sessionManager.isSessionActive {
                Text("Recording session — \(sessionManager.formattedElapsedTime)")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }

            if bleManager.isConnected || bleManager is MockBluetoothManager {
                liveTelemetryCard
            }

            // --- DATA LOG WINDOW ---
            VStack(alignment: .leading, spacing: 5) {
                Text("LIVE DATA STREAM")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding(.horizontal)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if bleManager.dataLog.isEmpty {
                                Text("Waiting for data...")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(Array(bleManager.dataLog.enumerated()), id: \.offset) { index, message in
                                    Text(message)
                                        .font(.system(.caption, design: .monospaced)) // Terminal-style font
                                        .foregroundColor(.green)
                                        .id(index) // Used for auto-scrolling
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 250) // Adjust this to make the window taller/shorter
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    // Auto-scroll to bottom when new data arrives
                    .onChange(of: bleManager.dataLog.count) { oldCount, newCount in
                        withAnimation {
                            if newCount > 0 {
                                proxy.scrollTo(newCount - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Spacer()

#if DEBUG && targetEnvironment(simulator)
            VStack(spacing: 10) {
                Button(action: {
                    syncDataManager.sendDebugMockBatchToServer()
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Mock Batch to Server")
                    }
                    .font(.subheadline)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                if let batchId = syncDataManager.lastDebugBatchId {
                    Text("Last debug batch: \(batchId.uuidString.prefix(8))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                if let receivedBatch = syncDataManager.lastReceivedBatchId {
                    Text("Last received batch: \(receivedBatch.uuidString.prefix(8))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                if let error = syncDataManager.lastSyncError {
                    Text("Sync error: \(error)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
#endif

            // --- CONNECT TO FIN (scan + autoconnect) ---
            if !bleManager.isConnected {
                Button(action: connectToSmartFin) {
                    HStack {
                        Image(systemName: bleManager.isSessionScanActive ? "xmark.circle" : "antenna.radiowaves.left.and.right")
                        Text(bleManager.isSessionScanActive ? "Cancel Scan" : "Connect to SmartFin")
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(bleManager.isSessionScanActive ? Color.gray : Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            // --- MANUAL SESSION (after BLE connected) ---
            if bleManager.isConnected {
                if sessionManager.isSessionActive {
                    Button(action: {
                        sessionManager.endSession()
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("End Session")
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    Button(action: startRecordingSession) {
                        HStack {
                            Image(systemName: "record.circle")
                            Text("Start Session")
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }

            // --- FIND DEVICE (manual picker) ---
            Button(action: {
                showBluetoothMenu = true
            }) {
                HStack {
                    Image(systemName: "wifi")
                    Text("Find Smartfin Device")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)

            NavigationLink {
                VisualizationView()
            } label: {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                    Text("View Past Sessions Summary")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.teal)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            .sheet(isPresented: $showBluetoothMenu) {
                BluetoothListView(bleManager: bleManager)
            }
        }
        .navigationTitle("Smartfin")
        .onAppear {
            sessionManager.bindBluetoothManager(bleManager)
        }
        .onChange(of: bleManager.discoveredPeripherals.count) { _, count in
            guard usesRealBluetooth, bleManager.isSessionScanActive, count > 1 else { return }
            showBluetoothMenu = true
        }
        .alert("Physical iPhone Required", isPresented: $showSimulatorConnectAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Connect to SmartFin uses real Bluetooth. Run on a physical iPhone to test with your fin.")
        }
        }
    }

    private func connectToSmartFin() {
        guard usesRealBluetooth else {
            showSimulatorConnectAlert = true
            return
        }
        if bleManager.isSessionScanActive {
            bleManager.stopSessionScan()
            bleManager.connectionStatus = "Bluetooth ready — tap Connect to SmartFin"
            return
        }
        bleManager.startSessionScan(autoConnect: true)
    }

    private func startRecordingSession() {
        let deviceName = bleManager.connectedDevice?.name ?? "SmartFin"
        sessionManager.prepareSession(deviceName: deviceName)
        sessionManager.startSession()
    }

    private var liveTelemetryCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.0f", bleManager.currentTemperature))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text("°F")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                Label(bleManager.waterStatus.capitalized, systemImage: waterIconName)
                    .font(.headline)
                    .foregroundColor(waterColor)

                if let imu = bleManager.lastIMU9, imu.count >= 3 {
                    Label(
                        String(format: "IMU %.1f, %.1f, %.1f", imu[0], imu[1], imu[2]),
                        systemImage: "move.3d"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var waterIconName: String {
        switch bleManager.waterStatus.lowercased() {
        case "in-water": return "drop.fill"
        case "dry": return "sun.max.fill"
        default: return "questionmark.circle"
        }
    }

    private var waterColor: Color {
        switch bleManager.waterStatus.lowercased() {
        case "in-water": return .blue
        case "dry": return .orange
        default: return .gray
        }
    }
}
