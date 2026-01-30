//
//  DeparturesView.swift
//  RT Bus
//
//  Created by Assistant on 29.12.2025.
//

import SwiftUI
import Combine
import OSLog
import RTBusCore

struct DeparturesView: View {
    let title: String
    let selectedLines: Set<BusLine>?
    let fetchAction: @MainActor () async throws -> [Departure]
    
    @State private var viewState: ViewState = .idle
    
    // Auto-refresh every 30 seconds
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    @Environment(\.dismiss) private var dismiss
    
    private enum ViewState {
        case idle
        case loading([Departure])
        case loaded([Departure])
        case error(String, [Departure])
        
        var departures: [Departure] {
            switch self {
            case .idle:
                return []
            case .loading(let departures),
                 .loaded(let departures),
                 .error(_, let departures):
                return departures
            }
        }
        
        var errorMessage: String? {
            if case .error(let message, _) = self {
                return message
            }
            return nil
        }
        
        var isLoading: Bool {
            if case .loading = self {
                return true
            }
            return false
        }
    }

    var body: some View {
        let departures = viewState.departures
        NavigationStack {
            List {
                if let errorMessage = viewState.errorMessage {
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
                } else if viewState.isLoading && departures.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if departures.isEmpty && !viewState.isLoading {
                    Text("ui.departures.noneFound")
                        .foregroundStyle(.secondary)
                }
                
                ForEach(departures) { departure in
                    DepartureRowView(departure: departure)
                        .accessibilityIdentifier("DepartureRow_\(departure.lineName)")
                }
            }
            .accessibilityIdentifier("DeparturesList")
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
                Task { @MainActor in
                    await loadDepartures()
                }
            }
            .refreshable {
                await loadDepartures()
            }
        }
    }
    
    @MainActor
    private func loadDepartures() async {
        // If specific lines are required but none selected, do nothing (handled by UI)
        if let selected = selectedLines, selected.isEmpty {
            viewState = .idle
            return
        }
        
        let currentDepartures = viewState.departures
        viewState = .loading(currentDepartures)
        do {
            let fetched = try await fetchAction()

            let nextState: ViewState = .loaded(fetched)
            withAnimation {
                viewState = nextState
            }
        } catch {
            Logger.ui.error("Error loading departures: \(error)")
            let message = errorMessageKey(for: error)
            viewState = .error(message, currentDepartures)
        }
    }

    private func errorMessageKey(for error: Error) -> String {
        if NetworkErrorMapper.isOffline(error) {
            return NSLocalizedString("ui.error.offline", comment: "")
        }
        return NSLocalizedString("ui.error.fetchFailed", comment: "")
    }
    
}

#Preview {
    DeparturesView(
        title: "Test Station",
        selectedLines: nil
    ) { @MainActor in
        let now = Int(Date().timeIntervalSince1970)
        // Midnight at start of day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let serviceDay = Int(startOfDay.timeIntervalSince1970)
        let secondsSinceMidnight = now - serviceDay
        
        return [
            Departure(
                lineName: "55",
                routeId: nil,
                headsign: "Rautatientori",
                scheduledTime: secondsSinceMidnight + 300,
                realtimeTime: secondsSinceMidnight + 300,
                serviceDay: serviceDay,
                platform: "5"
            ),
            Departure(
                lineName: "500",
                routeId: nil,
                headsign: "Munkkivuori",
                scheduledTime: secondsSinceMidnight + 600,
                realtimeTime: secondsSinceMidnight + 600,
                serviceDay: serviceDay,
                platform: "12"
            )
        ]
    }
}
