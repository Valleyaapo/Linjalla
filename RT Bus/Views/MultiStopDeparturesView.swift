//
//  MultiStopDeparturesView.swift
//  RT Bus
//
//  Created by Codex on 22.01.2026.
//

import SwiftUI
import Combine
import OSLog
import RTBusCore

struct MultiStopDeparturesView: View {
    let title: String
    let stops: [BusStop]
    let selectedLines: Set<BusLine>?
    let groupByStop: Bool
    let autoRefresh: Bool
    let fetchAction: @MainActor (BusStop) async throws -> [Departure]
    
    @State private var viewState: ViewState = .idle
    @State private var loadInFlight = false
    
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
    
    init(
        title: String,
        stops: [BusStop],
        selectedLines: Set<BusLine>?,
        groupByStop: Bool = true,
        autoRefresh: Bool = true,
        fetchAction: @escaping @MainActor (BusStop) async throws -> [Departure]
    ) {
        self.title = title
        self.stops = stops
        self.selectedLines = selectedLines
        self.groupByStop = groupByStop
        self.autoRefresh = autoRefresh
        self.fetchAction = fetchAction
    }

    var body: some View {
        NavigationStack {
            if autoRefresh {
                departuresList
                    .onReceive(refreshTimer) { _ in
                        Task { @MainActor in
                            await loadDepartures()
                        }
                    }
                    .refreshable {
                        await loadDepartures()
                    }
            } else {
                departuresList
            }
        }
    }

    private var departuresByStop: [String: [Departure]] {
        viewState.departures
    }

    private var allDepartures: [Departure] {
        departuresByStop.values
            .flatMap { $0 }
            .sorted { $0.departureDate < $1.departureDate }
    }

    private var departuresList: some View {
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
            } else if viewState.isLoading && allDepartures.isEmpty {
                ProgressView()
                    .accessibilityLabel(Text("ui.loading"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else if allDepartures.isEmpty && !viewState.isLoading {
                Text("ui.departures.noneFound")
                    .foregroundStyle(.secondary)
            }

            if groupByStop {
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
            } else {
                ForEach(allDepartures) { departure in
                    DepartureRowView(departure: departure)
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
    }
    
    @MainActor
    private func loadDepartures() async {
        guard !loadInFlight else { return }
        loadInFlight = true
        defer { loadInFlight = false }
        if let selected = selectedLines, selected.isEmpty {
            viewState = .idle
            return
        }
        
        let existingDepartures = viewState.departures
        viewState = .loading(existingDepartures)
        do {
            var rawByStop: [String: [Departure]] = [:]
            for stop in stops {
                try Task.checkCancellation()
                let fetched = try await fetchAction(stop)
                rawByStop[stop.id] = fetched
            }

            withAnimation {
                viewState = .loaded(rawByStop)
            }
        } catch {
            Logger.ui.error("Error loading multi-stop departures: \(error)")
            let message = errorMessageKey(for: error)
            viewState = .error(message, existingDepartures)
        }
    }

    private func errorMessageKey(for error: Error) -> String {
        if NetworkErrorMapper.isOffline(error) {
            return NSLocalizedString("ui.error.offline", comment: "")
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
