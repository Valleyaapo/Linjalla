//
//  ContentView.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import OSLog

struct ContentView: View {
    @Bindable var busManager: BusManager
    @Bindable var tramManager: TramManager
    @State private var stopManager: StopManager = { StopManager() }()
    @State private var mapStateManager = MapStateManager()
    @StateObject private var trainManager = TrainManager()
    @StateObject private var locationManager = LocationManager()
    
    /// HSL station ID for Rautatientori bus terminal
    private let rautatientoriStationId = "HSL:1000003"
    
    // Initial center: user location with fallback
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    @State private var selectedLines: Set<BusLine> = []
    @State private var isSearchPresented = false
    @State private var isDeparturesPresented = false
    @State private var isTrainDeparturesPresented = false
    @State private var showStops = true
    @State private var showStopNames = false
    @State private var isHSLErrorPresented = false
    
    var body: some View {
        mainContent
            .task(startupTask)
            .onChange(of: busManager.vehicleList, busListChanged)
            .onChange(of: tramManager.vehicleList, tramListChanged)
            .onChange(of: busManager.favoriteLines, busFavoritesChanged)
            .onChange(of: tramManager.favoriteLines, tramFavoritesChanged)
            .alert("ui.alert.busError", isPresented: busErrorBinding, actions: busErrorActions, message: busErrorMessage)
            .alert("ui.alert.tramError", isPresented: tramErrorBinding, actions: tramErrorActions, message: tramErrorMessage)
            .alert("ui.alert.stopError", isPresented: stopErrorBinding, actions: stopErrorActions, message: stopErrorMessage)
            .alert("ui.alert.hslAppMissing", isPresented: $isHSLErrorPresented, actions: hslErrorActions, message: hslErrorMessage)
    }
    
    // MARK: - Task and onChange Handlers
    
    private func startupTask() async {
        locationManager.requestAuthorization()
        Logger.ui.info("App started, requesting location")
        loadSelectedLines()
    }
    
    private func busListChanged(_ oldList: [BusModel], _ newList: [BusModel]) {
        mapStateManager.updateBuses(newList)
    }
    
    private func tramListChanged(_ oldList: [BusModel], _ newList: [BusModel]) {
        mapStateManager.updateTrams(newList)
    }
    
    private func busFavoritesChanged(_ oldFavorites: [BusLine], _ newFavorites: [BusLine]) {
        updateSelectionFromFavorites(old: oldFavorites, new: newFavorites)
    }
    
    private func tramFavoritesChanged(_ oldFavorites: [BusLine], _ newFavorites: [BusLine]) {
        updateSelectionFromFavorites(old: oldFavorites, new: newFavorites)
    }
    
    // MARK: - Alert Bindings and Views
    
    private var busErrorBinding: Binding<Bool> {
        Binding(
            get: { busManager.error != nil },
            set: { if !$0 { busManager.error = nil } }
        )
    }
    
    @ViewBuilder
    private func busErrorActions() -> some View {
        Button("ui.button.ok", role: .cancel) { busManager.error = nil }
    }
    
    @ViewBuilder
    private func busErrorMessage() -> some View {
        Text(busManager.error?.localizedDescription ?? "")
    }
    
    private var tramErrorBinding: Binding<Bool> {
        Binding(
            get: { tramManager.error != nil },
            set: { if !$0 { tramManager.error = nil } }
        )
    }
    
    @ViewBuilder
    private func tramErrorActions() -> some View {
        Button("ui.button.ok", role: .cancel) { tramManager.error = nil }
    }
    
    @ViewBuilder
    private func tramErrorMessage() -> some View {
        Text(tramManager.error?.localizedDescription ?? "")
    }
    
    private var stopErrorBinding: Binding<Bool> {
        Binding(
            get: { stopManager.error != nil },
            set: { if !$0 { stopManager.error = nil } }
        )
    }
    
    @ViewBuilder
    private func stopErrorActions() -> some View {
        Button("ui.button.ok", role: .cancel) { stopManager.error = nil }
    }
    
    @ViewBuilder
    private func stopErrorMessage() -> some View {
        Text(stopManager.error?.localizedDescription ?? "")
    }
    
    @ViewBuilder
    private func hslErrorActions() -> some View {
        Button("ui.button.ok", role: .cancel) {}
    }
    
    @ViewBuilder
    private func hslErrorMessage() -> some View {
        Text("ui.error.hslNotInstalled")
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            BusMapView(
                position: $position,
                vehicles: mapStateManager.vehicles,
                stops: stopManager.allStops,
                showStops: showStops,
                showStopNames: showStopNames,
                onCameraChange: handleCameraChange
            )
            
            SelectionOverlay(
                busLines: busManager.favoriteLines,
                tramLines: tramManager.favoriteLines,
                selectedLines: selectedLines,
                isLoading: stopManager.isLoading,
                onToggle: { toggleSelection(for: $0) },
                onSelectAll: { selectAllFavorites() },
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
                selectedLines: selectedLines
            ) {
                try await stopManager.fetchDepartures(for: rautatientoriStationId)
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
    
    private func updateSelectionFromFavorites(old: [BusLine], new: [BusLine]) {
        let oldSet = Set(old)
        let newSet = Set(new)
        
        let addedLines = newSet.subtracting(oldSet)
        let removedLines = oldSet.subtracting(newSet)
        
        var selectionChanged = false
        
        if !addedLines.isEmpty {
            selectedLines.formUnion(addedLines)
            selectionChanged = true
        }
        
        if !removedLines.isEmpty {
            selectedLines.subtract(removedLines)
            selectionChanged = true
        }
        
        if selectionChanged {
            saveSelectedLines()
            updateManagers()
        }
    }
    
    private func toggleSelection(for line: BusLine) {
        if selectedLines.contains(line) {
            selectedLines.remove(line)
        } else {
            selectedLines.insert(line)
        }
        saveSelectedLines()
        updateManagers()
    }
    
    private func saveSelectedLines() {
        if let encoded = try? JSONEncoder().encode(Array(selectedLines)) {
            UserDefaults.standard.set(encoded, forKey: "SelectedLinesState")
        }
    }
    
    private func loadSelectedLines() {
        if let data = UserDefaults.standard.data(forKey: "SelectedLinesState"),
           let decoded = try? JSONDecoder().decode([BusLine].self, from: data) {
            selectedLines = Set(decoded)
            updateManagers()
        }
    }
    
    private func updateManagers() {
        let selectedArray = Array(selectedLines)

        // Filter lines by type - each manager only gets its relevant lines
        let busLineIds = Set(busManager.favoriteLines.map { $0.id })
        let tramLineIds = Set(tramManager.favoriteLines.map { $0.id })

        let selectedBusLines = selectedArray.filter { busLineIds.contains($0.id) }
        let selectedTramLines = selectedArray.filter { tramLineIds.contains($0.id) }

        busManager.updateSubscriptions(selectedLines: selectedBusLines)
        tramManager.updateSubscriptions(selectedLines: selectedTramLines)
        stopManager.updateStops(for: selectedArray)
    }
    
    private func centerOnHelsinkiCentral() {
        let helsinkiCentral = CLLocationCoordinate2D(latitude: 60.1710, longitude: 24.9410)
        let region = MKCoordinateRegion(
            center: helsinkiCentral,
            span: MKCoordinateSpan(latitudeDelta: MapConstants.defaultSpanDelta, longitudeDelta: MapConstants.defaultSpanDelta)
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            position = .region(region)
        }
    }

    private func centerOnUser() {
        if let location = locationManager.lastLocation {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: MapConstants.defaultSpanDelta, longitudeDelta: MapConstants.defaultSpanDelta)
            )
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(region)
            }
        } else {
            locationManager.requestAuthorization()
        }
    }
    
    private func selectAllFavorites() {
        let allFavorites = busManager.favoriteLines + tramManager.favoriteLines
        
        if selectedLines.count == allFavorites.count && !allFavorites.isEmpty {
            selectedLines.removeAll()
        } else {
            selectedLines = Set(allFavorites)
        }
        saveSelectedLines()
        updateManagers()
    }

    private func openTickets() {
        guard let url = URL(string: "hslapp://tickets") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                 Logger.ui.warning("Could not open HSL tickets URL or app not installed")
                 isHSLErrorPresented = true
            }
        }
    }
    
    private func handleCameraChange(_ zoomLevel: Double) {
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
}

#Preview {
    ContentView(busManager: BusManager(), tramManager: TramManager())
}
