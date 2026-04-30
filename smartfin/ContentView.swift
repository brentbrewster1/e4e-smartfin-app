import SwiftUI

struct ContentView: View {
    // Use a lightweight simulator mock when running in Simulator so the UI can be
    // exercised without requiring real Bluetooth hardware. On a device the
    // real `BluetoothManager` will be used.
#if targetEnvironment(simulator)
    @StateObject var bleManager = MockBluetoothManager()
#else
    @StateObject var bleManager = BluetoothManager()
#endif
    @State private var showBluetoothMenu = false

    var body: some View {
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
                .foregroundColor(bleManager.connectionStatus.contains("Connected to") ? .green : .gray)
            
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
                    .onChange(of: bleManager.dataLog.count) { _ in
                        withAnimation {
                            proxy.scrollTo(bleManager.dataLog.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
            
            Spacer()
            
            // --- CONNECT BUTTON ---
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
            .padding(.bottom, 20)
            .sheet(isPresented: $showBluetoothMenu) {
                BluetoothListView(bleManager: bleManager)
            }
        }
    }
}
