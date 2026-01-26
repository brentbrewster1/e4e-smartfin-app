//
//  DashboardView.swift
//  smartfin
//
//  Created by Smartfin AI on 1/24/26.
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SurfingSession.startTime, order: .reverse) private var sessions: [SurfingSession]
    
    // Compute aggregates
    var totalWaves: Int {
        sessions.reduce(0) { $0 + $1.waveCount }
    }
    
    var maxSpeedRecord: Double {
        sessions.map { $0.maxSpeed }.max() ?? 0.0
    }
    
    var totalDistance: Double {
        sessions.reduce(0) { $0 + $1.totalDistance }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Welcome back,")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Surfer")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Summary Cards Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(title: "Total Waves", value: "\(totalWaves)", icon: "water.waves", color: .blue)
                        StatCard(title: "Top Speed", value: String(format: "%.1f mph", maxSpeedRecord), icon: "gauge.with.dots.needle.bottom.50percent", color: .orange)
                        StatCard(title: "Distance", value: String(format: "%.1f mi", totalDistance), icon: "map.fill", color: .green)
                        StatCard(title: "Sessions", value: "\(sessions.count)", icon: "surfboard.fill", color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // Charts Section
                    VStack(alignment: .leading) {
                        Text("Weekly Activity")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Chart {
                            ForEach(sessions.prefix(7).reversed()) { session in
                                BarMark(
                                    x: .value("Date", session.startTime, unit: .day),
                                    y: .value("Waves", session.waveCount)
                                )
                                .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top))
                                .cornerRadius(8)
                            }
                        }
                        .frame(height: 180)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Recent Sessions List
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Recent Sessions")
                                .font(.headline)
                            Spacer()
                            NavigationLink("View All") {
                                // Action to view all
                            }
                        }
                        .padding(.horizontal)
                        
                        ForEach(sessions.prefix(5)) { session in
                            SessionRow(session: session)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Dashboard") // Hidden by custom header usually or adaptable
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                if sessions.isEmpty {
                    loadMockData()
                }
            }
        }
    }
    
    func loadMockData() {
        // Pre-load mock data if empty
        let mocks = SurfingSession.mockData
        for mock in mocks {
            modelContext.insert(mock)
        }
    }
}

// MARK: - Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct SessionRow: View {
    let session: SurfingSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(session.locationName)
                    .font(.headline)
                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(session.waveCount) Waves")
                    .fontWeight(.semibold)
                Text(String(format: "%.1f mph", session.maxSpeed))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: SurfingSession.self, inMemory: true)
}
