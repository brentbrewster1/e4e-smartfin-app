//
//  VisualizationView.swift
//  smartfin
//
//  Created by Uliyaah Dionisio on 5/18/26.
//

import SwiftUI
import Charts

struct VisualizationView: View {
	@State private var chartSessions: [ChartSessionPoint] = []
	@State private var isLoading = false
	@State private var errorMessage: String?

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				Text("Last 30 Sessions")
					.font(.title2)
					.fontWeight(.semibold)

				if isLoading {
					ProgressView("Loading chart data...")
						.frame(maxWidth: .infinity, alignment: .center)
				} else if let errorMessage {
					ContentUnavailableView(
						"Could Not Load Data",
						systemImage: "exclamationmark.triangle",
						description: Text(errorMessage)
					)
				} else if chartSessions.isEmpty {
					ContentUnavailableView(
						"No Session Data",
						systemImage: "chart.bar.xaxis",
						description: Text("There are no sessions available from the server yet.")
					)
				} else {
					sessionTrendChart
					samplesChart
				}
			}
			.padding()
		}
		.navigationTitle("Visualizations")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button("Refresh") {
					Task {
						await loadSessionData()
					}
				}
				.disabled(isLoading)
			}
		}
		.task {
			await loadSessionData()
		}
	}

	private var sessionTrendChart: some View {
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

					PointMark(
						x: .value("Session", session.startedAt),
						y: .value("Avg Temp", avgTemperature)
					)
					.foregroundStyle(.orange)
				}
			}
			.frame(height: 260)
			.chartXAxis {
				AxisMarks(values: .automatic(desiredCount: 6))
			}
		}
	}

	private var samplesChart: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Samples Collected per Session")
				.font(.headline)

			Chart(chartSessions) { session in
				BarMark(
					x: .value("Session", session.startedAt),
					y: .value("Samples", session.samplesCollected)
				)
				.foregroundStyle(.teal)
			}
			.frame(height: 220)
			.chartXAxis {
				AxisMarks(values: .automatic(desiredCount: 6))
			}
		}
	}

	private func loadSessionData() async {
		isLoading = true
		errorMessage = nil

		do {
			let serverSessions = try await ServerManager.shared.getSessions()

			let latestThirty = serverSessions
				.sorted { $0.startedAt > $1.startedAt }
				.prefix(30)
				.reversed()

			chartSessions = latestThirty.map { session in
				ChartSessionPoint(
					id: session.id,
					startedAt: session.startedAt,
					durationMinutes: session.duration / 60,
					averageTemp: session.averageTemp,
					samplesCollected: session.samplesCollected
				)
			}
		} catch {
			errorMessage = error.localizedDescription
			chartSessions = []
		}

		isLoading = false
	}
}

private struct ChartSessionPoint: Identifiable {
	let id: UUID
	let startedAt: Date
	let durationMinutes: Double
	let averageTemp: Double?
	let samplesCollected: Int
}

#Preview {
	NavigationStack {
		VisualizationView()
	}
}
