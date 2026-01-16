//
//  BusMapView.swift
//  RT Bus
//
//  Created by Refactor on 01.01.2026.
//

import SwiftUI
import MapKit

// Wrapper for handling render state (including exit animations)
fileprivate struct RenderVehicle: Identifiable, Equatable {
    let item: MapItem
    var isExiting: Bool = false
    
    var id: String {
        switch item {
        case .bus(let bus): return "bus_\(bus.id)"
        case .tram(let tram): return "tram_\(tram.id)"
        case .stop(let stop): return "stop_\(stop.id)"
        }
    }
}

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
    
    /// Local state for rendering, including "ghost" vehicles exiting
    @State private var renderVehicles: [RenderVehicle] = []

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
    /// Uses renderVehicles which includes exiting ghosts
    private var visibleRenderVehicles: [RenderVehicle] {
        guard let region = visibleRegion else { return renderVehicles }

        let halfLatSpan = region.span.latitudeDelta * viewportBuffer / 2
        let halfLonSpan = region.span.longitudeDelta * viewportBuffer / 2

        return renderVehicles.filter { wrapper in
            let coord: CLLocationCoordinate2D
            switch wrapper.item {
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
            // 1. STOPS
            if showStops {
                ForEach(visibleStops) { stop in
                    MapCircle(center: stop.coordinate, radius: stopRadius)
                        .foregroundStyle(.white)
                        .stroke(.gray, lineWidth: 1)
                }
            }

            // 2. VEHICLES (from local render state)
            ForEach(visibleRenderVehicles) { wrapper in
                switch wrapper.item {
                case .bus(let bus):
                    Annotation("", coordinate: bus.coordinate) {
                        BusAnnotationView(lineName: bus.lineName, heading: bus.heading, color: .hslBlue)
                            .accessibilityLabel("Bus \(bus.lineName)")
                            .opacity(wrapper.isExiting ? 0 : 1)
                            .scaleEffect(wrapper.isExiting ? 0.5 : 1)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: wrapper.isExiting)
                            .animateEntry() // Handles entry
                            .id(bus.id)
                    }
                    .annotationTitles(.hidden)
                case .tram(let tram):
                    Annotation("", coordinate: tram.coordinate) {
                        BusAnnotationView(lineName: tram.lineName, heading: tram.heading, color: .hslGreen)
                            .accessibilityLabel("Tram \(tram.lineName)")
                            .opacity(wrapper.isExiting ? 0 : 1)
                            .scaleEffect(wrapper.isExiting ? 0.5 : 1)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: wrapper.isExiting)
                            .animateEntry() // Handles entry
                            .id(tram.id)
                    }
                    .annotationTitles(.hidden)
                case .stop:
                    EmptyMapContent()
                }
            }

            // 3. Stop Names
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
        .onChange(of: vehicles) { oldVehicles, newVehicles in
            updateRenderVehicles(old: oldVehicles, new: newVehicles)
        }
        .onAppear {
            // Initial load
            renderVehicles = vehicles.map { RenderVehicle(item: $0) }
        }
    }
    
    private func updateRenderVehicles(old: [MapItem], new: [MapItem]) {
        // 1. Identify removed vehicles (present in old but not in new)
        let newIds = Set(new.map { $0.id })
        let removedItems = old.filter { !newIds.contains($0.id) }
        
        // 2. Identify fresh vehicles (directly from new)
        var nextRenderList = new.map { RenderVehicle(item: $0) }
        
        // 3. Add "ghosts" for removed items, marked as exiting
        if !removedItems.isEmpty {
            let ghosts = removedItems.map { RenderVehicle(item: $0, isExiting: true) }
            nextRenderList.append(contentsOf: ghosts)
            
            // 4. Update immediately so new items appear ASAP (allowing animateEntry to handle fade-in)
            // We do NOT use withAnimation here because it delays the view insertion/layout
            renderVehicles = nextRenderList
            
            // 5. Schedule cleanup of ghosts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                // Remove ghosts that are stuck in exiting state
                // This removal CAN be animated if needed, or just silent since they are invisible (opacity 0)
                self.renderVehicles.removeAll { $0.isExiting }
            }
        } else {
            // Just update directly if no removals
            renderVehicles = nextRenderList
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
