//
//  UIKitMapView.swift
//  RT Bus
//
//  Created by Automation on 12.01.2026.
//

import SwiftUI
import MapKit

/// UIViewRepresentable wrapper for MKMapView with proper z-index control
struct UIKitMapView: UIViewRepresentable {
    
    // MARK: - Bindings
    
    @Binding var cameraTrigger: MKCoordinateRegion?
    
    // MARK: - Data
    
    let vehicles: [MapItem]
    let stops: [BusStop]
    var showStops: Bool
    var showStopNames: Bool
    let mapViewState: MapViewState
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        
        // Configure map
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.mapType = .standard
        
        // Start centered on Helsinki; user can recenter on their location manually.
        let helsinkiCentral = CLLocationCoordinate2D(latitude: 60.1710, longitude: 24.9410)
        let region = MKCoordinateRegion(
            center: helsinkiCentral,
            span: MKCoordinateSpan(latitudeDelta: MapConstants.defaultSpanDelta, longitudeDelta: MapConstants.defaultSpanDelta)
        )
        mapView.setRegion(region, animated: false)
        
        // Register annotation views
        mapView.register(
            VehicleAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: VehicleAnnotationView.reuseIdentifier
        )
        mapView.register(
            StopAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: StopAnnotationView.reuseIdentifier
        )
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update annotations with diffing
        context.coordinator.updateAnnotations(
            mapView: mapView,
            vehicles: vehicles,
            stops: showStops ? stops : [],
            showStops: showStops,
            showStopNames: showStopNames
        )
        
        // Handle Camera Trigger
        if let triggerRegion = cameraTrigger {
            mapView.setRegion(triggerRegion, animated: true)
            // Reset trigger on main thread to avoid update cycle issues
            DispatchQueue.main.async {
                cameraTrigger = nil
            }
        }
    }
    
    func makeCoordinator() -> MapViewCoordinator {
        MapViewCoordinator(mapViewState: mapViewState)
    }
}
