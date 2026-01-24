//
//  MultiStopDeparturesView.swift
//  RT Bus
//
//  Created by Codex on 22.01.2026.
//

import SwiftUI
import Combine
import OSLog

struct MultiStopDeparturesView: View {
    let title: String
    let stops: [BusStop]
    let selectedLines: Set<BusLine>?
    let fetchAction: (BusStop) async throws -> [Departure]
    
    @State private var viewState: ViewState = .idle
    
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    @Environment(\.dismiss) private var dismiss
    
    private enum ViewState {
        case idle
        case loading([String: [Departure]])
        case loaded([String: [Departure]])
        case error(String, [String: [Departure]])
        
        var departures: [String: [Departure]] {
            switch self {
            case .idle:
                return [:]
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
        let departuresByStop = viewState.departures
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
                } else if viewState.isLoading && departuresByStop.values.allSatisfy({ $0.isEmpty }) {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if departuresByStop.values.allSatisfy({ $0.isEmpty }) && !viewState.isLoading {
                    Text("ui.departures.noneFound")
                        .foregroundStyle(.secondary)
                }
                
                ForEach(stops) { stop in
                    Section(header: Text(sectionTitle(for: stop))) {
                        let departures = departuresByStop[stop.id] ?? []
                        if departures.isEmpty {
                            if !viewState.isLoading {
                                Text("ui.departures.noneFound")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(departures) { departure in
                                DepartureRowView(departure: departure)
                            }
                        }
                    }
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
    
    @MainActor
    private func loadDepartures() async {
        if let selected = selectedLines, selected.isEmpty {
            viewState = .idle
            return
        }
        
        let existingDepartures = viewState.departures
        viewState = .loading(existingDepartures)
        do {
            let selectedNames: Set<String>? = selectedLines.map { Set($0.map { $0.shortName }) }
            var rawByStop: [String: [Departure]] = [:]
            try await withThrowingTaskGroup(of: (String, [Departure]).self) { group in
                for stop in stops {
                    group.addTask {
                        let fetched = try await fetchAction(stop)
                        return (stop.id, fetched)
                    }
                }
                
                for try await (stopId, departures) in group {
                    rawByStop[stopId] = departures
                }
            }
            
            let now = Date()
            var results: [String: [Departure]] = [:]
            for (stopId, departures) in rawByStop {
                var valid = departures.filter { $0.departureDate > now }
                if let selectedNames {
                    valid = valid.filter { selectedNames.contains($0.lineName) }
                }
                valid.sort { $0.departureDate < $1.departureDate }
                results[stopId] = valid
            }
            
            withAnimation {
                viewState = .loaded(results)
            }
        } catch {
            Logger.ui.error("Error loading multi-stop departures: \(error)")
            let message = errorMessageKey(for: error)
            viewState = .error(message, existingDepartures)
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
    
    private func sectionTitle(for stop: BusStop) -> String {
        let nameCounts = Dictionary(grouping: stops, by: { $0.name })
        if let count = nameCounts[stop.name]?.count, count > 1 {
            return "\(stop.name) • \(stop.id)"
        }
        return stop.name
    }
    
}
