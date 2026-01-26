//
//  BusMapView.swift
//  RT Bus
//
//  Created by Aapo Laakso on 01.01.2026.
//

import SwiftUI
import MapKit
import RTBusCore

struct BusMapView: View {
    @Binding var cameraTrigger: MKCoordinateRegion?
    @Bindable var mapViewState: MapViewState
    let vehicles: [MapItem]
    let stops: [BusStop]

    var body: some View {
        UIKitMapView(
            cameraTrigger: $cameraTrigger,
            vehicles: vehicles,
            stops: stops,
            showStops: mapViewState.showStops,
            showStopNames: mapViewState.showStopNames,
            mapViewState: mapViewState
        )
        .ignoresSafeArea()
    }
}

#Preview {
    BusMapView(
        cameraTrigger: .constant(nil),
        mapViewState: MapViewState(),
        vehicles: [
            .bus(BusModel(id: 1, lineName: "55", routeId: "HSL:1055", latitude: 60.171, longitude: 24.941, heading: 45, timestamp: Date().timeIntervalSince1970)),
            .tram(BusModel(id: 2, lineName: "4", routeId: "HSL:1004", latitude: 60.172, longitude: 24.942, heading: 90, timestamp: Date().timeIntervalSince1970))
        ],
        stops: [
            BusStop(id: "1", name: "Test Stop", latitude: 60.17, longitude: 24.94)
        ]
    )
}
