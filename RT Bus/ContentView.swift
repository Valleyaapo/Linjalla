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

struct ContentView: View {
    @Bindable var busManager: BusManager
    @Bindable var tramManager: TramManager
    @State private var selectionStore: SelectionStore
    @State private var mapStateManager = MapStateManager()
    @StateObject private var trainManager = TrainManager()
    @StateObject private var locationManager = LocationManager()
    
    /// HSL station ID for Rautatientori bus terminal
    private let rautatientoriStationId = "HSL:1000003"
    
    // Trigger for programmatic camera updates
    @State private var cameraTrigger: MKCoordinateRegion? = nil
    
    @State private var isSearchPresented = false
    @State private var isDeparturesPresented = false
    @State private var isTrainDeparturesPresented = false
    @State private var showStops = true
    @State private var showStopNames = false
    @State private var selectedStop: BusStop?

    init(busManager: BusManager, tramManager: TramManager) {
        self.busManager = busManager
        self.tramManager = tramManager
        _selectionStore = State(initialValue: SelectionStore(busManager: busManager, tramManager: tramManager))
    }

    var body: some View {
        mainContent
            .task(startupTask)
            .onChange(of: busManager.vehicleList, busListChanged)
            .onChange(of: tramManager.vehicleList, tramListChanged)
            .onChange(of: busManager.favoriteLines, busFavoritesChanged)
            .onChange(of: tramManager.favoriteLines, tramFavoritesChanged)
            .sheet(item: $selectedStop) { stop in
                DeparturesView(
                    title: stop.name,
                    selectedLines: nil
                ) {
                    try await selectionStore.stopManager.fetchDepartures(for: stop.id)
                }
                .presentationDetents([.medium, .large])
            }
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            BusMapView(
                cameraTrigger: $cameraTrigger,
                vehicles: currentVehicles,
                stops: selectionStore.stopManager.allStops,
                showStops: showStops,
                showStopNames: showStopNames,
                onCameraChange: handleCameraChange,
                onStopTapped: { stop in selectedStop = stop }
            )
            
            SelectionOverlay(
                busLines: busManager.favoriteLines,
                tramLines: tramManager.favoriteLines,
                selectedLines: selectionStore.selectedLines,
                isLoading: selectionStore.stopManager.isLoading,
                onToggle: { selectionStore.toggleSelection(for: $0) },
                onSelectAll: { selectionStore.selectAllFavorites() },
                onAdd: { isSearchPresented = true },
                onDepartures: { isDeparturesPresented = true },
                onTrainDepartures: { isTrainDeparturesPresented = true },
                onCenter: { centerOnHelsinkiCentral() },
                onCenterUser: { centerOnUser() },
                onTickets: { openTickets() }
            )
        }
        .sheet(isPresented: $isSearchPresented) {
            LineSearchSheet(busManager: busManager, tramManager: tramManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isDeparturesPresented) {
            DeparturesView(
                title: NSLocalizedString("ui.location.rautatientori", comment: ""),
                selectedLines: selectionStore.selectedLines
            ) {
                try await selectionStore.stopManager.fetchDepartures(for: rautatientoriStationId)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isTrainDeparturesPresented) {
            DeparturesView(
                title: NSLocalizedString("ui.location.helsinkiCentral", comment: ""),
                selectedLines: nil
            ) {
                try await trainManager.fetchDepartures(stationCode: "HKI")
            }
            .presentationDetents([.medium, .large])
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
        if let location = locationManager.lastLocation {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: MapConstants.defaultSpanDelta, longitudeDelta: MapConstants.defaultSpanDelta)
            )
            cameraTrigger = region
        } else {
            locationManager.requestAuthorization()
        }
    }
    
    func handleCameraChange(_ zoomLevel: Double) {
        let shouldShowStops = zoomLevel < MapConstants.showStopsThreshold
        let shouldShowStopNames = zoomLevel < MapConstants.showStopNamesThreshold
        
        if showStops != shouldShowStops {
            withAnimation(.easeInOut(duration: 0.3)) {
                showStops = shouldShowStops
            }
        }
        if showStopNames != shouldShowStopNames {
            withAnimation(.easeInOut(duration: 0.2)) {
                showStopNames = shouldShowStopNames
            }
        }
    }
    
    func openTickets() {
        guard let url = URL(string: "hslapp://tickets") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                 Logger.ui.warning("Could not open HSL tickets URL or app not installed")
            }
        }
    }
    
    func startupTask() async {
        locationManager.requestAuthorization()
        Logger.ui.info("App started, requesting location")
        selectionStore.loadSelectedLines()
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

extension ContentView {
    var busErrorBinding: Binding<Bool> {
        Binding(
            get: { busManager.error != nil },
            set: { if !$0 { busManager.error = nil } }
        )
    }
    
    var tramErrorBinding: Binding<Bool> {
        Binding(
            get: { tramManager.error != nil },
            set: { if !$0 { tramManager.error = nil } }
        )
    }
    
    var stopErrorBinding: Binding<Bool> {
        Binding(
            get: { selectionStore.stopManager.error != nil },
            set: { if !$0 { selectionStore.stopManager.clearError() } }
        )
    }
    
    func busErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) { busManager.error = nil })
    }
    
    func tramErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) { tramManager.error = nil })
    }
    
    func stopErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) { selectionStore.stopManager.clearError() })
    }
    
    func hslErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) {})
    }
    
    func busErrorMessage() -> AnyView {
        AnyView(Text(busManager.error?.localizedDescription ?? ""))
    }
    
    func tramErrorMessage() -> AnyView {
        AnyView(Text(tramManager.error?.localizedDescription ?? ""))
    }
    
    func stopErrorMessage() -> AnyView {
        AnyView(Text(selectionStore.stopManager.error?.localizedDescription ?? ""))
    }
    
    func hslErrorMessage() -> AnyView {
        AnyView(Text("ui.error.hslNotInstalled"))
    }
}

#Preview {
    ContentView(busManager: BusManager(), tramManager: TramManager())
}
