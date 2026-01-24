//
//  MapViewCoordinator.swift
//  RT Bus
//
//  Coordinates between SwiftUI and MKMapView with centralized animation state
//

import MapKit
import CoreLocation

/// Coordinates between SwiftUI and MKMapView
final class MapViewCoordinator: NSObject {
    
    // MARK: - Callbacks
    
    private let onCameraChange: (Double) -> Void
    private let onStopTapped: ((StopSelection) -> Void)?
    
    // MARK: - State
    
    private var vehicleAnnotations: [String: VehicleAnnotation] = [:]
    private var stopAnnotations: [String: StopAnnotation] = [:]
    private var currentZoomLevel: Double = 0.05
    private var latestStops: [BusStop] = []
    
    // Debouncing for stop updates
    private var lastStopRefreshZoom: Double = 0.05
    
    // Centralized animation state management
    private let animationStateManager = AnimationStateManager()
    
    // MARK: - Initialization
    
    init(onCameraChange: @escaping (Double) -> Void, onStopTapped: ((StopSelection) -> Void)?) {
        self.onCameraChange = onCameraChange
        self.onStopTapped = onStopTapped
        super.init()
    }
    
    // MARK: - Annotation Management
    
    func updateAnnotations(
        mapView: MKMapView,
        vehicles: [MapItem],
        stops: [BusStop],
        showStops: Bool,
        showStopNames: Bool
    ) {
        latestStops = stops
        // MARK: Process Vehicles
        
        var newVehicleAnnotations: [String: VehicleAnnotation] = [:]
        var vehiclesToAnimate: [(key: String, annotation: VehicleAnnotation, isNew: Bool)] = []
        
        for item in vehicles {
            switch item {
            case .bus(let bus):
                let key = "bus_\(bus.id)"
                processVehicle(key: key, model: bus, type: .bus, mapView: mapView,
                              newAnnotations: &newVehicleAnnotations, toAnimate: &vehiclesToAnimate)
                
            case .tram(let tram):
                let key = "tram_\(tram.id)"
                processVehicle(key: key, model: tram, type: .tram, mapView: mapView,
                              newAnnotations: &newVehicleAnnotations, toAnimate: &vehiclesToAnimate)
                
            case .stop:
                break // Handled separately
            }
        }
        
        // Handle vehicles that need to be removed
        let vehiclesToRemove = vehicleAnnotations.filter { newVehicleAnnotations[$0.key] == nil }
        for (key, annotation) in vehiclesToRemove {
            // Check if this vehicle was pending removal and reappeared
            if animationStateManager.isPendingRemoval(vehicleId: key) {
                // Already animating out - will be removed by completion handler
                continue
            }
            
            let state = animationStateManager.state(for: key)
            let generation = state.beginExiting()
            animationStateManager.markPendingRemoval(vehicleId: key, annotation: annotation, generation: generation)
            
            if let view = mapView.view(for: annotation) as? VehicleAnnotationView {
                view.animateExit { [weak self, weak mapView] in
                    guard let self = self, let mapView = mapView else { return }
                    // Only remove if this completion is still valid
                    if let annotationToRemove = self.animationStateManager.validatePendingRemoval(vehicleId: key, generation: generation) {
                        mapView.removeAnnotation(annotationToRemove)
                        self.animationStateManager.removeState(for: key)
                    }
                }
            } else {
                // No view (off-screen), remove immediately
                mapView.removeAnnotation(annotation)
                _ = animationStateManager.validatePendingRemoval(vehicleId: key, generation: generation)
                animationStateManager.removeState(for: key)
            }
        }
        
        vehicleAnnotations = newVehicleAnnotations
        
        // Trigger animations for new/updated vehicles after view is assigned
        triggerVehicleAnimations(mapView: mapView, vehicles: vehiclesToAnimate)
        
        // MARK: Process Stops
        
        var newStopAnnotations: [String: StopAnnotation] = [:]
        
        if showStops {
            for stop in stops {
                let key = stop.id
                if let existing = stopAnnotations[key] {
                    existing.showName = showStopNames
                    newStopAnnotations[key] = existing
                    if let view = mapView.view(for: existing) as? StopAnnotationView {
                        view.configure(with: existing, zoomLevel: currentZoomLevel)
                    }
                } else {
                    let annotation = StopAnnotation(stop: stop, showName: showStopNames)
                    newStopAnnotations[key] = annotation
                    mapView.addAnnotation(annotation)
                }
            }
        }
        
        // Remove stale stops
        let stopsToRemove = stopAnnotations.filter { newStopAnnotations[$0.key] == nil }
        if !stopsToRemove.isEmpty {
            mapView.removeAnnotations(Array(stopsToRemove.values))
        }
        stopAnnotations = newStopAnnotations
    }
    
    // MARK: - Vehicle Processing Helpers
    
    private func processVehicle(
        key: String,
        model: BusModel,
        type: VehicleAnnotation.VehicleType,
        mapView: MKMapView,
        newAnnotations: inout [String: VehicleAnnotation],
        toAnimate: inout [(key: String, annotation: VehicleAnnotation, isNew: Bool)]
    ) {
        // Check if vehicle was pending removal (reappeared during exit animation)
        if let _ = animationStateManager.cancelPendingRemoval(vehicleId: key) {
            // Reappeared! Cancel removal and update existing
            if let existing = vehicleAnnotations[key] {
                let shouldAnimate = mapView.view(for: existing) != nil
                existing.update(from: model, animate: shouldAnimate)
                newAnnotations[key] = existing
                toAnimate.append((key: key, annotation: existing, isNew: false))
                return
            }
        }
        
        if let existing = vehicleAnnotations[key] {
            let shouldAnimate = mapView.view(for: existing) != nil
            existing.update(from: model, animate: shouldAnimate)
            newAnnotations[key] = existing
            toAnimate.append((key: key, annotation: existing, isNew: false))
        } else {
            let annotation = VehicleAnnotation(model: model, type: type)
            newAnnotations[key] = annotation
            mapView.addAnnotation(annotation)
            toAnimate.append((key: key, annotation: annotation, isNew: true))
        }
    }
    
    private func triggerVehicleAnimations(
        mapView: MKMapView,
        vehicles: [(key: String, annotation: VehicleAnnotation, isNew: Bool)]
    ) {
        for (key, annotation, isNew) in vehicles {
            guard let view = mapView.view(for: annotation) as? VehicleAnnotationView else { continue }
            
            let state = animationStateManager.state(for: key)
            
            if isNew {
                // Entry animation handled via viewFor/prepareForDisplay.
                continue
            } else {
                // Update animation (heading)
                let generation = state.beginUpdating(to: annotation.coordinate, heading: annotation.headingDegrees)
                view.animateUpdate(
                    toHeading: annotation.headingDegrees,
                    headingVelocity: state.headingVelocity
                ) {
                    state.complete(generation: generation)
                }
            }
        }
    }
    
}

// MARK: - MKMapViewDelegate

extension MapViewCoordinator: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // User location uses default blue dot
        if annotation is MKUserLocation {
            return nil
        }
        
        // Vehicle annotations
        if let vehicle = annotation as? VehicleAnnotation {
            guard let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: VehicleAnnotationView.reuseIdentifier,
                for: annotation
            ) as? VehicleAnnotationView else {
                return nil
            }
            
            // Configure layout only - animation is triggered by updateAnnotations
            view.configure(with: vehicle)
            view.setHeading(vehicle.headingDegrees) // Set initial heading without animation
            
            if vehicle.needsEntryAnimation {
                vehicle.markEntryAnimationHandled()
                let state = animationStateManager.state(for: vehicle.identifier)
                let generation = state.beginEntering()
                view.queueEntryAnimation(heading: vehicle.headingDegrees) {
                    state.complete(generation: generation)
                }
            }
            return view
        }
        
        // Stop annotations
        if let stop = annotation as? StopAnnotation {
            guard let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: StopAnnotationView.reuseIdentifier,
                for: annotation
            ) as? StopAnnotationView else {
                return nil
            }
            
            view.configure(with: stop, zoomLevel: currentZoomLevel)
            return view
        }
        
        // Cluster annotations
        if let cluster = annotation as? MKClusterAnnotation {
            guard let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                for: annotation
            ) as? MKMarkerAnnotationView else {
                return nil
            }
            
            view.markerTintColor = .gray
            view.glyphText = "\(cluster.memberAnnotations.count)"
            view.displayPriority = .defaultLow
            return view
        }
        
        return nil
    }

    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        if let stopAnnotation = annotation as? StopAnnotation {
            let nearbyStops = mergedStops(around: stopAnnotation.stop)
            let selection = StopSelection(
                id: nearbyStops.map { $0.id }.sorted().joined(separator: "|"),
                title: selectionTitle(for: nearbyStops),
                stops: nearbyStops
            )
            onStopTapped?(selection)
            mapView.deselectAnnotation(annotation, animated: false)
            return
        }
        
        if let cluster = annotation as? MKClusterAnnotation {
            let members = cluster.memberAnnotations.compactMap { $0 as? StopAnnotation }
            guard !members.isEmpty else {
                mapView.deselectAnnotation(annotation, animated: false)
                return
            }
            let stops = members.map { $0.stop }.sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }
                return lhs.name < rhs.name
            }
            let title = selectionTitle(for: stops)
            let selection = StopSelection(
                id: stops.map { $0.id }.sorted().joined(separator: "|"),
                title: title,
                stops: stops
            )
            if stops.count >= 2 {
                onStopTapped?(selection)
            } else if let single = stops.first {
                onStopTapped?(StopSelection(id: single.id, title: single.name, stops: [single]))
            }
            mapView.deselectAnnotation(annotation, animated: false)
            return
        }
        
        mapView.deselectAnnotation(annotation, animated: false)
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        let zoomLevel = mapView.region.span.latitudeDelta
        
        if abs(currentZoomLevel - zoomLevel) > 0.001 {
            currentZoomLevel = zoomLevel
            onCameraChange(zoomLevel)
        }
        
        if abs(lastStopRefreshZoom - zoomLevel) > 0.005 {
            lastStopRefreshZoom = zoomLevel
            refreshStopVisuals(mapView: mapView, zoomLevel: zoomLevel)
        }
    }
    
    private func refreshStopVisuals(mapView: MKMapView, zoomLevel: Double) {
        for annotation in mapView.annotations(in: mapView.visibleMapRect) {
            if let stop = annotation as? StopAnnotation,
               let view = mapView.view(for: stop) as? StopAnnotationView {
                view.configure(with: stop, zoomLevel: zoomLevel)
            }
        }
    }

    private func mergedStops(around stop: BusStop) -> [BusStop] {
        guard !latestStops.isEmpty else { return [stop] }
        let target = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
        let nearby = latestStops.filter { candidate in
            let location = CLLocation(latitude: candidate.latitude, longitude: candidate.longitude)
            let distance = target.distance(from: location)
            if distance <= MapConstants.stopMergeDistanceMeters {
                return true
            }
            return candidate.name == stop.name && distance <= MapConstants.stopNameMergeDistanceMeters
        }
        let stops = nearby.isEmpty ? [stop] : nearby
        return stops.sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.id < rhs.id
            }
            return lhs.name < rhs.name
        }
    }

    private func selectionTitle(for stops: [BusStop]) -> String {
        let uniqueNames = Set(stops.map { $0.name })
        return uniqueNames.count == 1 ? (stops.first?.name ?? "") : NSLocalizedString("ui.stops.nearby", comment: "")
    }
}
