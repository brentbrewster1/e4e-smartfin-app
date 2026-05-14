//
//  FinConnectionViews.swift
//  smartfinwatchos Watch App
//

import CoreBluetooth
import SwiftUI

struct ConnectionView: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack {
            if bluetoothManager.discoveredPeripherals.isEmpty {
                SearchingView(status: bluetoothManager.connectionStatus)
            } else if bluetoothManager.discoveredPeripherals.count == 1 {
                SingleDeviceView(
                    device: bluetoothManager.discoveredPeripherals.first!,
                    onConnect: { peripheral in
                        bluetoothManager.connect(to: peripheral)
                    }
                )
            } else {
                MultipleDevicesView(
                    devices: bluetoothManager.discoveredPeripherals,
                    onConnect: { peripheral in
                        bluetoothManager.connect(to: peripheral)
                    }
                )
            }
        }
        .onAppear {
            if bluetoothManager.centralManager?.state == .poweredOn {
                bluetoothManager.startScanning()
            }
        }
    }
}

struct SearchingView: View {
    let status: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)

            Text(status)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct SingleDeviceView: View {
    let device: CBPeripheral
    let onConnect: (CBPeripheral) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "water.waves.and.arrow.down")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            VStack(spacing: 4) {
                Text("Connect to")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                Text(device.name ?? "SmartFin")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: { onConnect(device) }) {
                Text("Connect")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}

struct MultipleDevicesView: View {
    let devices: [CBPeripheral]
    let onConnect: (CBPeripheral) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Select SmartFin")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top)

            List(devices, id: \.identifier) { device in
                Button(action: { onConnect(device) }) {
                    HStack {
                        Image(systemName: "water.waves")
                            .foregroundColor(.blue)

                        Text(device.name ?? "SmartFin")
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
        }
    }
}
