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
    @Environment(BusManager.self) private var busManager
    @Environment(TramManager.self) private var tramManager
    @Environment(SelectionStore.self) private var selectionStore
    @State private var mapStateManager = MapStateManager()
    @State private var trainManager = TrainManager()
    @State private var locationManager = LocationManager()
    
    /// HSL station ID for Rautatientori bus terminal
    private let rautatientoriStationId = "HSL:1000003"
    
    // Trigger for programmatic camera updates
    @State private var cameraTrigger: MKCoordinateRegion? = nil
    
    @State private var isSearchPresented = false
    @State private var isDeparturesPresented = false
    @State private var isTrainDeparturesPresented = false
    @State private var showStops = true
    @State private var showStopNames = false
    @State private var selectedStop: StopSelection?
    @State private var showHslAppMissingAlert = false
    @State private var didCenterOnUser = false

    var body: some View {
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
            }
            .sheet(item: $selectedStop) { selection in
                if selection.stops.count >= 2 {
                    MultiStopDeparturesView(
                        title: selection.title,
                        stops: selection.stops,
                        selectedLines: nil
                    ) { stop in
                        try await selectionStore.stopManager.fetchDepartures(for: stop.id)
                    }
                    .presentationDetents([.medium, .large])
                } else if let stop = selection.stops.first {
                    DeparturesView(
                        title: stop.name,
                        selectedLines: nil
                    ) {
                        try await selectionStore.stopManager.fetchDepartures(for: stop.id)
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            .alert("ui.error.title", isPresented: busErrorBinding, actions: busErrorActions, message: busErrorMessage)
            .alert("ui.error.title", isPresented: tramErrorBinding, actions: tramErrorActions, message: tramErrorMessage)
            .alert("ui.error.title", isPresented: stopErrorBinding, actions: stopErrorActions, message: stopErrorMessage)
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            BusMapView(
                cameraTrigger: $cameraTrigger,
                vehicles: currentVehicles,
                stops: mapStateManager.stopsList,
                showStops: showStops,
                showStopNames: showStopNames,
                onCameraChange: handleCameraChange,
                onStopTapped: { selection in selectedStop = selection }
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
            LineSearchSheet()
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
        if let location = locationManager.lastLocation {
            centerOnLocation(location)
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
                 DispatchQueue.main.async {
                     showHslAppMissingAlert = true
                 }
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
    let busManager = BusManager(connectOnStart: false)
    let tramManager = TramManager(connectOnStart: false)
    let selectionStore = SelectionStore(busManager: busManager, tramManager: tramManager)
    return ContentView()
        .environment(busManager)
        .environment(tramManager)
        .environment(selectionStore)
}
