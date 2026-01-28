//
//  Handles HTTP communication through relaying bluetooth data to a server, effectively storing it for conservation purposes.
//
//  Created by Brent Brewster on 1/28/26.
//

import Foundation

class NetworkManager {
    // This allows calling of NetworkManager.shared
    static let shared = NetworkManager()
    
    private init() {} // This prevents creating extra instances by mistake
    
    func uploadBluetoothData(value: String, deviceID: String) {
        // REPLACE WITH SERVER URL
        guard let url = URL(string: "https://your-server.com/api/ingest") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let json: [String: Any] = [
            "deviceID": deviceID,
            "value": value,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [])
        } catch {
            print("JSON Encoding Error: \(error)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Upload failed: \(error.localizedDescription)")
            } else {
                print("Data sent successfully.")
            }
        }
        task.resume()
    }
}
