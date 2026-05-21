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

            VStack(spacing: 2) {
                Text("Temp")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(String(format: "%.1f°F", bluetoothManager.currentTemperature))
                    .font(.system(size: 33, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: bluetoothManager.currentTemperature)
                Text(String(format: "%.1f°C · %@", bluetoothManager.currentTemperatureCelsius, bluetoothManager.waterStatus))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .monospacedDigit()
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

            liveDataSection

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

    private var liveDataSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LIVE DATA")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if bluetoothManager.dataLog.isEmpty {
                            Text("Waiting for data...")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.gray)
                        } else {
                            ForEach(Array(bluetoothManager.dataLog.suffix(liveLineCount).enumerated()), id: \.offset) { index, message in
                                Text(message)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(message.contains("(!)") ? .orange : .green)
                                    .id(index)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: liveLogHeight)
                .background(Color.black.opacity(0.85))
                .cornerRadius(8)
                .onChange(of: bluetoothManager.dataLog.count) { _ in
                    let last = max(0, bluetoothManager.dataLog.count - 1)
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    #if os(watchOS)
    private var liveLineCount: Int { 10 }
    private var liveLogHeight: CGFloat { 72 }
    #else
    private var liveLineCount: Int { 16 }
    private var liveLogHeight: CGFloat { 140 }
    #endif
}
