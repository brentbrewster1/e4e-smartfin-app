//
//  SessionDetailView.swift
//  smartfin
//

import SwiftUI

struct SessionDetailView: View {
    let session: SessionData

    @State private var readings: [SessionReadingRecord] = []
    @State private var loadBanner: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)

                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(label: "Duration", value: session.formattedDuration)
                    DetailRow(label: "Samples", value: "\(session.samplesCollected)")
                    DetailRow(label: "Avg Temp", value: String(format: "%.1f°F", session.averageTemp))
                    DetailRow(label: "Device", value: session.deviceName)
                }

                if let loadBanner {
                    Text(loadBanner)
                        .font(.caption2)
                        .foregroundColor(loadBanner.hasPrefix("Could not") ? .orange : .gray)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !readings.isEmpty {
                    Text("Saved samples (\(readings.count))")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 4)

                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(readings.enumerated()), id: \.offset) { index, reading in
                            SessionReadingRowView(index: index, reading: reading)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .task(id: session.id) {
            applyLoadResult(SessionReadingsFileStore.loadReadings(sessionId: session.id))
        }
    }

    private func applyLoadResult(_ result: SessionReadingsFileStore.LoadResult) {
        switch result {
        case .noFile:
            readings = []
            loadBanner = "No saved sample file for this session."
        case .decodeFailed(let message):
            readings = []
            loadBanner = "Could not read samples: \(message)"
        case .success(let rows):
            readings = rows
            loadBanner = nil
        }
    }
}

private struct SessionReadingRowView: View {
    let index: Int
    let reading: SessionReadingRecord

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("#\(index + 1)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("type \(reading.ensembleType)")
                    .font(.caption)
                    .foregroundColor(.white)
                Spacer()
                Text(Self.timeFormatter.string(from: reading.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 6) {
                Text(String(format: "%.0f°F", reading.temperature))
                    .font(.caption)
                Text(reading.waterStatus)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if let finDs = reading.finElapsedTimeDeciseconds {
                Text("fin \(finDs) ds")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if let imuLine = Self.imuSummary(reading) {
                Text(imuLine)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }

    private static func imuSummary(_ reading: SessionReadingRecord) -> String? {
        let values: [Double]?
        if let matrix = reading.imuMatrix, !matrix.isEmpty {
            values = matrix
        } else if let samples = reading.imuSamples, let first = samples.first, !first.isEmpty {
            values = first
        } else {
            values = nil
        }
        guard let v = values, !v.isEmpty else { return nil }
        let prefix = v.prefix(9)
        let parts = prefix.map { String(format: "%.3f", $0) }
        let extra = v.count > prefix.count ? " … (\(v.count) values)" : ""
        return "IMU: " + parts.joined(separator: ", ") + extra
    }
}
