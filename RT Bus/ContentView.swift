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
    @State var stopManager: StopManager = { StopManager() }()
    @State var mapStateManager = MapStateManager()
    @StateObject var trainManager = TrainManager()
    @StateObject var locationManager = LocationManager()
    
    /// HSL station ID for Rautatientori bus terminal
    let rautatientoriStationId = "HSL:1000003"
    
    // Trigger for programmatic camera updates
    @State var cameraTrigger: MKCoordinateRegion? = nil
    
    @State var selectedLines: Set<BusLine> = []
    @State var isSearchPresented = false
    @State var isDeparturesPresented = false
    @State var isTrainDeparturesPresented = false
    @State var selectedStop: BusStop?
    @State var showStops = true
    @State var showStopNames = false
    @State var isHSLErrorPresented = false
    
    var body: some View {
        contentWithLogic
            .sheet(item: $selectedStop) { stop in
                DeparturesView(
                    title: stop.name,
                    selectedLines: nil
                ) {
                    try await stopManager.fetchDepartures(for: stop.id)
                }
                .presentationDetents([.medium, .large])
            }
    }
    
    @ViewBuilder
    private var contentWithLogic: some View {
        mainContent
            .modifier(TasksAndChangeModifiers(
                startupTask: startupTask,
                busVehicleList: busManager.vehicleList,
                tramVehicleList: tramManager.vehicleList,
                busFavoriteLines: busManager.favoriteLines,
                tramFavoriteLines: tramManager.favoriteLines,
                busListChanged: busListChanged,
                tramListChanged: tramListChanged,
                busFavoritesChanged: busFavoritesChanged,
                tramFavoritesChanged: tramFavoritesChanged
            ))
            .modifier(AlertsModifier(
                busErrorBinding: busErrorBinding,
                tramErrorBinding: tramErrorBinding,
                stopErrorBinding: stopErrorBinding,
                isHSLErrorPresented: $isHSLErrorPresented,
                busErrorActions: busErrorActions,
                tramErrorActions: tramErrorActions,
                stopErrorActions: stopErrorActions,
                hslErrorActions: hslErrorActions,
                busErrorMessage: busErrorMessage,
                tramErrorMessage: tramErrorMessage,
                stopErrorMessage: stopErrorMessage,
                hslErrorMessage: hslErrorMessage
            ))
    }
    
    // MARK: - Main Content
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            BusMapView(
                cameraTrigger: $cameraTrigger,
                vehicles: mapStateManager.vehicles,
                stops: stopManager.allStops,
                showStops: showStops,
                showStopNames: showStopNames,
                onCameraChange: handleCameraChange,
                onStopTapped: { stop in selectedStop = stop }
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
}

#Preview {
    ContentView(busManager: BusManager(), tramManager: TramManager())
}
