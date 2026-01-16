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
    let rautatientoriStationId = "HSL:1000003"
    
    // Trigger for programmatic camera updates
    @State var cameraTrigger: MKCoordinateRegion? = nil
    
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
                vehicles: mapStateManager.vehicles,
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
}

#Preview {
    ContentView(busManager: BusManager(), tramManager: TramManager())
}
