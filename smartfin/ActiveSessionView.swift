//
//  ActiveSessionView.swift
//  smartfin
//

import SwiftUI

struct ActiveSessionView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var bluetoothManager: BluetoothManager
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            Text(sessionManager.formattedElapsedTime)
                .font(.system(size: 35, weight: .medium, design: .rounded))
                .foregroundColor(.green)
                .monospacedDigit()

            VStack(spacing: 1) {
                Text("Temp")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(String(format: "%.0f°F", sessionManager.currentTemperature))
                    .font(.system(size: 33, weight: .semibold))
                    .foregroundColor(.white)
            }

            HStack(spacing: 2) {
                Text("GPS")
                    .font(.caption)
                    .foregroundColor(.gray)
                Image(systemName: sessionManager.gpsEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(sessionManager.gpsEnabled ? .green : .gray)
            }

            Text("\(sessionManager.samplesCollected) samples")
                .font(.caption2)
                .foregroundColor(.gray)

            #if os(iOS)
            liveDataSection
            #endif

            Spacer()

            Button(action: onEnd) {
                Text("End Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }

    #if os(iOS)
    private var liveDataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LIVE DATA")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if bluetoothManager.dataLog.isEmpty {
                        Text("Waiting for data...")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.gray)
                    } else {
                        ForEach(Array(bluetoothManager.dataLog.suffix(8).enumerated()), id: \.offset) { _, message in
                            Text(message)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            .background(Color.black.opacity(0.85))
            .cornerRadius(8)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    #endif
}
