//
//  DeparturesView.swift
//  RT Bus
//
//  Created by Assistant on 29.12.2025.
//

import SwiftUI
import Combine
import OSLog

struct DeparturesView: View {
    let title: String
    let selectedLines: Set<BusLine>?
    let fetchAction: () async throws -> [Departure]
    
    @State private var departures: [Departure] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // TD-002: Static formatter to avoid recreation per cell
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Auto-refresh every 30 seconds
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else if let selected = selectedLines, selected.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("ui.departures.noLines", comment: ""),
                        systemImage: "bus.fill",
                        description: Text("ui.departures.selectHint")
                    )
                    .listRowBackground(Color.clear)
                } else if isLoading && departures.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if departures.isEmpty && !isLoading {
                    Text("ui.departures.noneFound")
                        .foregroundStyle(.secondary)
                }
                
                ForEach(departures) { departure in
                    HStack(spacing: 12) {
                        Text(departure.lineName)
                            .font(.title3.bold())
                            .fontDesign(.rounded)
                            .frame(minWidth: 50, alignment: .leading)
                            .foregroundColor(.hslBlue)
                        
                        VStack(alignment: .leading) {
                            Text(departure.headsign)
                                .font(.headline)
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                if let platform = departure.platform {
                                    Text(String(format: NSLocalizedString("ui.label.platform", comment: ""), platform))
                                        .font(.caption.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                Text(formatTime(departure.departureDate))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Real-time indicator (simplified)
                        Text(timeUntil(departure.departureDate))
                            .font(.callout.monospacedDigit())
                            .bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.green)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(departure.lineName) \(NSLocalizedString("to", comment: "")) \(departure.headsign). \(timeUntil(departure.departureDate))"
                    )
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(Text("ui.button.done"))
                }
            }
            .listStyle(.insetGrouped)
            .task {
                await loadDepartures()
            }
            .onReceive(refreshTimer) { _ in
                Task {
                    await loadDepartures()
                }
            }
            .refreshable {
                await loadDepartures()
            }
        }
    }
    
    private func loadDepartures() async {
        // If specific lines are required but none selected, do nothing (handled by UI)
        if let selected = selectedLines, selected.isEmpty {
            self.departures = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await fetchAction()
            
            // Filter out past departures
            let now = Date()
            var valid = fetched.filter { $0.departureDate > now }
            
            // Apply line filter if needed
            if let selected = selectedLines {
                let selectedNames = Set(selected.map { $0.shortName })
                valid = valid.filter { selectedNames.contains($0.lineName) }
            }
            
            withAnimation {
                self.departures = valid
                self.isLoading = false
            }
        } catch {
            Logger.ui.error("Error loading departures: \(error)")
            errorMessage = errorMessageKey(for: error)
            self.isLoading = false
        }
    }

    private func errorMessageKey(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return NSLocalizedString("ui.error.offline", comment: "")
            default:
                break
            }
        }
        return NSLocalizedString("ui.error.fetchFailed", comment: "")
    }
    
    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }
    
    private func timeUntil(_ date: Date) -> String {
        let diff = Int(date.timeIntervalSinceNow / 60)
        if diff <= 0 {
            return NSLocalizedString("ui.time.now", comment: "")
        }
        return String(format: NSLocalizedString("ui.time.min", comment: ""), diff)
    }
}

#Preview {
    DeparturesView(
        title: "Test Station",
        selectedLines: nil
    ) {
        let now = Int(Date().timeIntervalSince1970)
        // Midnight at start of day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let serviceDay = Int(startOfDay.timeIntervalSince1970)
        let secondsSinceMidnight = now - serviceDay
        
        return [
            Departure(
                lineName: "55",
                headsign: "Rautatientori",
                scheduledTime: secondsSinceMidnight + 300,
                realtimeTime: secondsSinceMidnight + 300,
                serviceDay: serviceDay,
                platform: "5"
            ),
            Departure(
                lineName: "500",
                headsign: "Munkkivuori",
                scheduledTime: secondsSinceMidnight + 600,
                realtimeTime: secondsSinceMidnight + 600,
                serviceDay: serviceDay,
                platform: "12"
            )
        ]
    }
}
