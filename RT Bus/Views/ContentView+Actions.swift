//
//  ContentView+Actions.swift
//  RT Bus
//
//  Action handlers for ContentView
//

import SwiftUI
import MapKit
import CoreLocation
import OSLog

extension ContentView {
    
    // MARK: - Map Actions
    
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
    
    // MARK: - External Actions
    
    func openTickets() {
        guard let url = URL(string: "hslapp://tickets") else { return }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                 Logger.ui.warning("Could not open HSL tickets URL or app not installed")
            }
        }
    }
    
    // MARK: - Task Handlers
    
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
