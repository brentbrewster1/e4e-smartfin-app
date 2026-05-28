//
//  VisualizationView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 5/18/26.
//

import SwiftUI
import Charts

struct VisualizationView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Saved Sessions")
                    .font(.title2)
                    .fontWeight(.semibold)

                if sessionManager.savedSessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Connect to your SmartFin, start a session, then end it to see data here.")
                    )
                } else {
                    summaryCharts
                    sessionList
                }
            }
            .padding()
        }
        .navigationTitle("Past Sessions")
    }

    private var sortedSessions: [SessionData] {
        sessionManager.savedSessions.sorted { $0.startedAt > $1.startedAt }
    }

    private var summaryCharts: some View {
        let chartSessions = sortedSessions.prefix(30).reversed().map { session in
            ChartSessionPoint(
                id: session.id,
                startedAt: session.startedAt,
                durationMinutes: session.duration / 60,
                averageTemp: session.averageTemp,
                samplesCollected: session.samplesCollected
            )
        }

        return Group {
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration + Avg Temperature")
                    .font(.headline)

                Chart(chartSessions) { session in
                    BarMark(
                        x: .value("Session", session.startedAt),
                        y: .value("Duration (min)", session.durationMinutes)
                    )
                    .foregroundStyle(.blue.gradient)
                    .opacity(0.45)

                    if let avgTemperature = session.averageTemp {
                        LineMark(
                            x: .value("Session", session.startedAt),
                            y: .value("Avg Temp", avgTemperature)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 220)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Samples per Session")
                    .font(.headline)

                Chart(chartSessions) { session in
                    BarMark(
                        x: .value("Session", session.startedAt),
                        y: .value("Samples", session.samplesCollected)
                    )
                    .foregroundStyle(.teal)
                }
                .frame(height: 180)
            }
        }
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Details")
                .font(.headline)

            ForEach(sortedSessions) { session in
                NavigationLink {
                    LocalSessionDetailView(session: session)
                } label: {
                    SessionSummaryRow(session: session, readings: sessionManager.readings(for: session.id))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SessionSummaryRow: View {
    let session: SessionData
    let readings: [SessionReadingRecord]

    private var tempSampleCount: Int {
        readings.filter { $0.ensembleType == "01" }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.formattedDate)
                    .font(.headline)
                Spacer()
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(session.deviceName)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Label("\(readings.count) samples", systemImage: "waveform.path.ecg")
                Label("\(tempSampleCount) temp", systemImage: "thermometer")
                if let avg = session.averageTemp {
                    Label(String(format: "%.0f°F avg", avg), systemImage: "gauge")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct LocalSessionDetailView: View {
    @EnvironmentObject var sessionManager: SessionManager
    let session: SessionData

    private var readings: [SessionReadingRecord] {
        sessionManager.readings(for: session.id)
    }

    private var temperaturePoints: [TemperatureChartPoint] {
        readings
            .filter { $0.ensembleType == "01" }
            .compactMap { record in
                guard let temp = record.temperature else { return nil }
                return TemperatureChartPoint(timestamp: record.timestamp, fahrenheit: temp)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.deviceName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(session.formattedDate) · \(session.formattedTime)")
                        .foregroundColor(.secondary)
                    Text("Duration \(session.formattedDuration) · \(readings.count) samples")
                        .foregroundColor(.secondary)
                }

                if temperaturePoints.isEmpty {
                    ContentUnavailableView(
                        "No Temperature Data",
                        systemImage: "thermometer",
                        description: Text("This session has no type 01 readings saved.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Temperature (°F)")
                            .font(.headline)

                        Chart(temperaturePoints) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("°F", point.fahrenheit)
                            )
                            .foregroundStyle(.orange)
                            PointMark(
                                x: .value("Time", point.timestamp),
                                y: .value("°F", point.fahrenheit)
                            )
                            .foregroundStyle(.orange)
                        }
                        .frame(height: 240)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reading Breakdown")
                        .font(.headline)

                    let tempCount = readings.filter { $0.ensembleType == "01" }.count
                    let imuCount = readings.filter { $0.ensembleType == "0C" }.count
                    Text("\(tempCount) temperature + water · \(imuCount) IMU")
                        .foregroundColor(.secondary)

                    if let lastWater = readings.last(where: { $0.ensembleType == "01" })?.waterStatus {
                        Label("Last water status: \(lastWater)", systemImage: "drop.fill")
                    }
                }

                if let lastIMU = readings.last(where: { $0.ensembleType == "0C" })?.imuSamples?.first,
                   lastIMU.count >= 9 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest IMU Sample")
                            .font(.headline)
                        Text(
                            String(
                                format: "accel %.2f, %.2f, %.2f · gyro %.2f, %.2f, %.2f",
                                lastIMU[0], lastIMU[1], lastIMU[2],
                                lastIMU[3], lastIMU[4], lastIMU[5]
                            )
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ChartSessionPoint: Identifiable {
    let id: UUID
    let startedAt: Date
    let durationMinutes: Double
    let averageTemp: Double?
    let samplesCollected: Int
}

private struct TemperatureChartPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let fahrenheit: Double
}

#Preview {
    NavigationStack {
        VisualizationView()
            .environmentObject(SessionManager())
    }
}
