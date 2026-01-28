import SwiftUI

struct ContentView: View {
    @StateObject var bleManager = BluetoothManager()
    @State private var showBluetoothMenu = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // --- LOGO REPLACES TEXT HERE ---
            Image("SmartfinLogo")  // Make sure this matches the name in Assets exactly!
                .resizable()       // Allows the image to be resized
                .scaledToFit()     // Keeps the logo proportions correct
                .frame(width: 300) // Adjusts the width (change this number to make it bigger/smaller)
                .padding(.top, 20)
                .colorInvert()
            
            // Show current connection status
            Text(bleManager.connectionStatus)
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
            
            Spacer()
            
            // BUTTON TO OPEN MENU
            Button(action: {
                showBluetoothMenu = true
            }) {
                HStack {
                    Image(systemName: "wifi")
                    Text("Find Smartfin Device")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.teal)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .sheet(isPresented: $showBluetoothMenu) {
                BluetoothListView(bleManager: bleManager)
            }
            
            Spacer().frame(height: 20)
        }
    }
}
