//
//  StopMergingBenchmark.swift
//  RT BusTests
//
//  Benchmark for stop merging logic.
//

import Testing
import CoreLocation
import MapKit
import Foundation
@testable import RT_Bus
import RTBusCore

@MainActor
@Suite
struct StopMergingBenchmark {

    @Test
    func measureStopMergingPerformance() {
        // Setup
        let center = CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384) // Helsinki
        let numberOfStops = 10000
        var stops: [BusStop] = []

        // Generate random stops around Helsinki (roughly 20km radius)
        for i in 0..<numberOfStops {
            let latOffset = Double.random(in: -0.2...0.2)
            let lonOffset = Double.random(in: -0.4...0.4)
            stops.append(BusStop(
                id: "stop_\(i)",
                name: "Stop \(i % 100)", // Reuse names to trigger name merge logic
                latitude: center.latitude + latOffset,
                longitude: center.longitude + lonOffset
            ))
        }

        let mapViewState = MapViewState()
        let coordinator = MapViewCoordinator(mapViewState: mapViewState)

        // Inject stops by calling updateAnnotations
        // We use a dummy MKMapView. In a real environment this might need a host application or specific setup.
        let mapView = MKMapView()
        coordinator.updateAnnotations(
            mapView: mapView,
            vehicles: [],
            stops: stops,
            showStops: true,
            showStopNames: true
        )

        // Pick a target stop in the middle
        let targetStop = stops[0]
        let targetAnnotation = StopAnnotation(stop: targetStop, showName: true)

        // Measure
        let iterations = 100
        let start = Date()

        // Note: mergedStops is internal.

        for _ in 0..<iterations {
            _ = coordinator.mergedStops(around: targetAnnotation)
        }

        let end = Date()
        let duration = end.timeIntervalSince(start)
        print("Benchmark (Conceptual): Time for \(iterations) merges with \(numberOfStops) stops: \(duration) seconds")
    }
}
