//
//  UIKitMapView.swift
//  RT Bus
//
//  Created by Automation on 12.01.2026.
//

import SwiftUI
import MapKit
import UIKit
import RTBusCore

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
    let trainStations: [TrainStation]
    let onTrainStationTap: (TrainStation) -> Void
    let onBusDepartures: () -> Void
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        
        // Configure map
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        mapView.mapType = .standard
        configureTouchHandling(for: mapView)
        
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
            MapAnchorAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MapAnchorAnnotationView.reuseIdentifier
        )
        mapView.register(
            TrainStationAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: TrainStationAnnotationView.reuseIdentifier
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
            trainStations: trainStations,
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
        MapViewCoordinator(
            mapViewState: mapViewState,
            onTrainStationTap: onTrainStationTap,
            onBusTap: onBusDepartures
        )
    }

    private func configureTouchHandling(for mapView: MKMapView) {
        // Reduce tap delay on annotation buttons by disabling scroll-view touch delay.
        if let scrollView = mapView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            scrollView.delaysContentTouches = false
            scrollView.canCancelContentTouches = true
        }
        mapView.gestureRecognizers?.forEach { recognizer in
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
        }
    }
}
