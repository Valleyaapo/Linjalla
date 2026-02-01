//
//  ContentView.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import SwiftUI
import MapKit
import CoreLocation
import OSLog
import RTBusCore

struct ContentView: View {
    @Environment(BusManager.self) private var busManager
    @Environment(TramManager.self) private var tramManager
    @Environment(SelectionStore.self) private var selectionStore
    @State private var mapStateManager = MapStateManager()
    @State private var mapViewState = MapViewState()
    @State private var trainManager = TrainManager()
    @State private var locationManager = LocationManager()
    
    /// HSL station ID for Rautatientori bus terminal
    private let rautatientoriStationId = "HSL:1000003"
    
    // Trigger for programmatic camera updates
    @State private var cameraTrigger: MKCoordinateRegion? = nil
    
    @State private var isSearchPresented = false
    @State private var isDeparturesPresented = false
    @State private var selectedTrainStation: TrainStation?
    @State private var showHslAppMissingAlert = false
    @State private var didCenterOnUser = false
    @State private var showLocationErrorAlert = false

    var body: some View {
        @Bindable var mapViewState = mapViewState
        mainContent
            .task(startupTask)
            .onChange(of: busManager.vehicleList, busListChanged)
            .onChange(of: tramManager.vehicleList, tramListChanged)
            .onChange(of: busManager.favoriteLines, busFavoritesChanged)
            .onChange(of: tramManager.favoriteLines, tramFavoritesChanged)
            .onChange(of: selectionStore.stopManager.allStops, initial: true) { _, newValue in
                mapStateManager.updateStops(newValue)
            }
            .onChange(of: locationManager.lastLocation, initial: true) { _, newValue in
                guard !didCenterOnUser, let location = newValue else { return }
                didCenterOnUser = true
                centerOnLocation(location)
                showLocationErrorAlert = false
            }
            .sheet(item: $mapViewState.selectedStop) { selection in
                if selection.stops.count >= 2 {
                    MultiStopDeparturesView(
                        title: selection.title,
                        stops: selection.stops,
                        selectedLines: nil
                    ) { @MainActor stop in
                        try await selectionStore.stopManager.fetchDepartures(for: stop.id)
                    }
                    .presentationDetents([.medium, .large])
                } else if let stop = selection.stops.first {
                    DeparturesView(
                        title: stop.name,
                        selectedLines: nil
                    ) { @MainActor in
                        try await selectionStore.stopManager.fetchDepartures(for: stop.id)
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .alert("ui.error.title", isPresented: locationErrorBinding, actions: locationErrorActions, message: locationErrorMessage)
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            BusMapView(
                cameraTrigger: $cameraTrigger,
                mapViewState: mapViewState,
                vehicles: currentVehicles,
                stops: mapStateManager.stopsList,
                trainStations: trainManager.stations,
                onTrainStationTap: { station in
                    presentTrainDepartures(for: station)
                },
                onBusDepartures: { presentDepartures() }
            )
            
            SelectionOverlay(
                busLines: busManager.favoriteLines,
                tramLines: tramManager.favoriteLines,
                selectedLines: selectionStore.selectedLines,
                isLoading: selectionStore.stopManager.isLoading,
                onToggle: { selectionStore.toggleSelection(for: $0) },
                onSelectAll: { selectionStore.selectAllFavorites() },
                onAdd: { isSearchPresented = true },
                onCenter: { centerOnHelsinkiCentral() },
                onCenterUser: { centerOnUser() },
                onTickets: { openTickets() }
            )
        }
        .sheet(isPresented: $isSearchPresented) {
            LineSearchSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isDeparturesPresented) {
            DeparturesView(
                title: NSLocalizedString("ui.location.rautatientori", comment: ""),
                selectedLines: selectionStore.selectedLines
            ) { @MainActor in
                let filter = DepartureFilterInput.from(selectionStore.selectedLines)
                return try await selectionStore.stopManager.fetchStationDepartures(
                    for: rautatientoriStationId,
                    filter: filter
                )
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedTrainStation) { station in
            DeparturesView(
                title: station.name,
                selectedLines: nil
            ) { @MainActor in
                try await selectionStore.stopManager.fetchStationDepartures(for: station.id)
            }
            .presentationDetents([.medium, .large])
        }
        .alert(Text("ui.error.hslNotInstalled"), isPresented: $showHslAppMissingAlert) {
            Button("ui.button.ok", role: .cancel) {}
        }
    }

    private var currentVehicles: [MapItem] {
        let vehicles = mapStateManager.vehicles
        if !vehicles.isEmpty {
            return vehicles
        }

        var fallback: [MapItem] = []
        fallback.append(contentsOf: busManager.vehicleList.map { .bus($0) })
        fallback.append(contentsOf: tramManager.vehicleList.map { .tram($0) })
        return fallback
    }
}

// MARK: - Actions

extension ContentView {
    func centerOnHelsinkiCentral() {
        let helsinkiCentral = CLLocationCoordinate2D(latitude: 60.1710, longitude: 24.9410)
        let region = MKCoordinateRegion(
            center: helsinkiCentral,
            span: MKCoordinateSpan(latitudeDelta: MapConstants.defaultSpanDelta, longitudeDelta: MapConstants.defaultSpanDelta)
        )
        cameraTrigger = region
    }

    func centerOnUser() {
        showLocationErrorAlert = true
        if let location = locationManager.lastLocation {
            centerOnLocation(location)
            showLocationErrorAlert = false
        } else {
            locationManager.requestAuthorization()
        }
    }

    func centerOnLocation(_ location: CLLocation) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: MapConstants.defaultSpanDelta, longitudeDelta: MapConstants.defaultSpanDelta)
        )
        cameraTrigger = region
    }
    
    func openTickets() {
        guard let url = URL(string: "hslapp://tickets") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                 Logger.ui.warning("Could not open HSL tickets URL or app not installed")
                 DispatchQueue.main.async {
                     showHslAppMissingAlert = true
                 }
            }
        }
    }
    
    func startupTask() async {
        locationManager.requestAuthorization()
        selectionStore.loadSelectedLines()
        await trainManager.fetchStations()
    }
    
    func busListChanged(_ oldList: [BusModel], _ newList: [BusModel]) {
        mapStateManager.updateBuses(newList)
    }
    
    func tramListChanged(_ oldList: [BusModel], _ newList: [BusModel]) {
        mapStateManager.updateTrams(newList)
    }
    
    func busFavoritesChanged(_ oldFavorites: [BusLine], _ newFavorites: [BusLine]) {
        selectionStore.syncFavorites(old: oldFavorites, new: newFavorites)
    }
    
    func tramFavoritesChanged(_ oldFavorites: [BusLine], _ newFavorites: [BusLine]) {
        selectionStore.syncFavorites(old: oldFavorites, new: newFavorites)
    }
}

// MARK: - Presentation

private extension ContentView {
    func presentDepartures() {
        var transaction = Transaction()
        transaction.animation = .snappy(duration: 0.18)
        withTransaction(transaction) {
            isDeparturesPresented = true
        }
    }

    func presentTrainDepartures(for station: TrainStation) {
        var transaction = Transaction()
        transaction.animation = .snappy(duration: 0.18)
        withTransaction(transaction) {
            selectedTrainStation = station
        }
    }
}

// MARK: - Selection

extension ContentView {
    func toggleSelection(for line: BusLine) {
        selectionStore.toggleSelection(for: line)
    }

    func loadSelectedLines() {
        selectionStore.loadSelectedLines()
    }

    func selectAllFavorites() {
        selectionStore.selectAllFavorites()
    }
}

// MARK: - Alerts

// MARK: - Alerts (user-action triggered only)

extension ContentView {
    var locationErrorBinding: Binding<Bool> {
        Binding(
            get: { showLocationErrorAlert && locationManager.error != nil },
            set: {
                if !$0 {
                    locationManager.clearError()
                    showLocationErrorAlert = false
                }
            }
        )
    }

    func locationErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) { locationManager.clearError() })
    }

    func locationErrorMessage() -> AnyView {
        AnyView(Text(locationManager.error?.localizedDescription ?? ""))
    }
}

#Preview {
    let busManager = BusManager(connectOnStart: false)
    let tramManager = TramManager(connectOnStart: false)
    let selectionStore = SelectionStore(busManager: busManager, tramManager: tramManager)
    return ContentView()
        .environment(busManager)
        .environment(tramManager)
        .environment(selectionStore)
}
