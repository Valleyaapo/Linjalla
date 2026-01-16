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
    
    // Initial center: user location with fallback
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    
    @State private var isSearchPresented = false
    @State private var isDeparturesPresented = false
    @State private var isTrainDeparturesPresented = false
    @State private var showStops = true
    @State private var showStopNames = false

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
    }
    
    // MARK: - Task and onChange Handlers
    
    private func startupTask() async {
        locationManager.requestAuthorization()
        Logger.ui.info("App started, requesting location")
        selectionStore.loadSelectedLines()
    }
    
    private func busListChanged(_ oldList: [BusModel], _ newList: [BusModel]) {
        mapStateManager.updateBuses(newList)
    }
    
    private func tramListChanged(_ oldList: [BusModel], _ newList: [BusModel]) {
        mapStateManager.updateTrams(newList)
    }
    
    private func busFavoritesChanged(_ oldFavorites: [BusLine], _ newFavorites: [BusLine]) {
        selectionStore.syncFavorites(old: oldFavorites, new: newFavorites)
    }
    
    private func tramFavoritesChanged(_ oldFavorites: [BusLine], _ newFavorites: [BusLine]) {
        selectionStore.syncFavorites(old: oldFavorites, new: newFavorites)
    }
    
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            BusMapView(
                position: $position,
                vehicles: mapStateManager.vehicles,
                stops: selectionStore.stopManager.allStops,
                showStops: showStops,
                showStopNames: showStopNames,
                onCameraChange: handleCameraChange
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
    
    private func openTickets() {
        guard let url = URL(string: "hslapp://tickets") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                 Logger.ui.warning("Could not open HSL tickets URL or app not installed")
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
