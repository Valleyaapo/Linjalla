//
//  BusMapView.swift
//  RT Bus
//
//  Created by Refactor on 01.01.2026.
//

import SwiftUI
import MapKit

struct BusMapView: View {
    @Binding var position: MapCameraPosition
    let vehicles: [MapItem]
    let stops: [BusStop]
    var showStops: Bool = true
    var showStopNames: Bool = false
    let onCameraChange: (Double) -> Void

    /// Fixed stop radius in meters
    private let stopRadius: CLLocationDistance = 8

    /// Buffer multiplier for viewport culling (1.2 = 20% beyond visible area)
    private let viewportBuffer: Double = 1.3

    /// Track visible region for culling
    @State private var visibleRegion: MKCoordinateRegion?

    // MARK: - Viewport Culling

    /// Filter stops to only those within the visible viewport + buffer
    private var visibleStops: [BusStop] {
        guard let region = visibleRegion else { return stops }

        let halfLatSpan = region.span.latitudeDelta * viewportBuffer / 2
        let halfLonSpan = region.span.longitudeDelta * viewportBuffer / 2

        return stops.filter { stop in
            abs(stop.latitude - region.center.latitude) <= halfLatSpan &&
            abs(stop.longitude - region.center.longitude) <= halfLonSpan
        }
    }

    /// Filter vehicles to only those within the visible viewport + buffer
    private var visibleVehicles: [MapItem] {
        guard let region = visibleRegion else { return vehicles }

        let halfLatSpan = region.span.latitudeDelta * viewportBuffer / 2
        let halfLonSpan = region.span.longitudeDelta * viewportBuffer / 2

        return vehicles.filter { item in
            let coord: CLLocationCoordinate2D
            switch item {
            case .bus(let bus): coord = bus.coordinate
            case .tram(let tram): coord = tram.coordinate
            case .stop: return false
            }

            return abs(coord.latitude - region.center.latitude) <= halfLatSpan &&
                   abs(coord.longitude - region.center.longitude) <= halfLonSpan
        }
    }

    // MARK: - Body

    var body: some View {
        Map(position: $position, interactionModes: .all) {
            // 1. STOPS - Using MapCircle so they render BELOW vehicle Annotations
            if showStops {
                ForEach(visibleStops) { stop in
                    MapCircle(center: stop.coordinate, radius: stopRadius)
                        .foregroundStyle(.white)
                        .stroke(.gray, lineWidth: 1)
                }
            }

            // 2. VEHICLES - Using Annotation so they render ABOVE MapCircles
            ForEach(visibleVehicles) { item in
                switch item {
                case .bus(let bus):
                    Annotation("", coordinate: bus.coordinate) {
                        BusAnnotationView(lineName: bus.lineName, heading: bus.heading, color: .hslBlue)
                            .accessibilityLabel("Bus \(bus.lineName)")
                    }
                    .annotationTitles(.hidden)
                case .tram(let tram):
                    Annotation("", coordinate: tram.coordinate) {
                        BusAnnotationView(lineName: tram.lineName, heading: tram.heading, color: .hslGreen)
                            .accessibilityLabel("Tram \(tram.lineName)")
                    }
                    .annotationTitles(.hidden)
                case .stop:
                    EmptyMapContent()
                }
            }

            // 3. Stop Names (when zoomed in close enough)
            if showStopNames {
                ForEach(visibleStops) { stop in
                    Annotation("", coordinate: stop.coordinate, anchor: .top) {
                        Text(stop.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                            .offset(y: 8)
                    }
                    .annotationTitles(.hidden)
                }
            }

            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
        .onMapCameraChange { context in
            visibleRegion = context.region
            onCameraChange(context.region.span.latitudeDelta)
        }
    }
}

#Preview {
    BusMapView(
        position: .constant(.automatic),
        vehicles: [
            .bus(BusModel(id: 1, lineName: "55", routeId: "HSL:1055", latitude: 60.171, longitude: 24.941, heading: 45, timestamp: Date().timeIntervalSince1970)),
            .tram(BusModel(id: 2, lineName: "4", routeId: "HSL:1004", latitude: 60.172, longitude: 24.942, heading: 90, timestamp: Date().timeIntervalSince1970))
        ],
        stops: [
            BusStop(id: "1", name: "Test Stop", latitude: 60.17, longitude: 24.94)
        ],
        showStopNames: true,
        onCameraChange: { _ in }
    )
}
