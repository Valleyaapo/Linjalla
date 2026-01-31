//
//  TramManager.swift
//  RT Bus
//
//  Created by Assistant on 03.01.2026.
//

import Foundation
import SwiftUI
import Observation
import RTBusCore

@MainActor
@Observable
final class TramManager: BaseVehicleManager {

    // MARK: - Configuration Overrides

    nonisolated override var vehicleType: BusModel.VehicleType { .tram }
    nonisolated override var topicPrefix: String { "tram" }
    nonisolated override var transportMode: TransportMode { .tram }
    nonisolated override var favoritesKey: String { "FavoriteTramLines" }

    override var defaultFavorites: [BusLine] {
        [
            BusLine(id: "HSL:1004", shortName: "4", longName: "Katajanokka - Munkkiniemi"),
            BusLine(id: "HSL:1009", shortName: "9", longName: "Länsiterminaali - Pasila"),
            BusLine(id: "HSL:1010", shortName: "10", longName: "Kirurgi - Pikku Huopalahti")
        ]
    }

    // MARK: - Initialization

    override init(urlSession: URLSession = .shared, connectOnStart: Bool = true) {
        super.init(urlSession: urlSession, connectOnStart: connectOnStart)
        setup()
    }

    // MARK: - Mock Simulation

    override func startMockSimulation() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let centerLat = 60.1719
            let centerLon = 24.9414
            let now = Date().timeIntervalSince1970

            let tram4 = BusModel(
                id: 8004,
                lineName: "4",
                routeId: "HSL:1004",
                latitude: centerLat + Double.random(in: -0.002...0.002),
                longitude: centerLon + Double.random(in: -0.002...0.002),
                heading: Int.random(in: 0...360),
                timestamp: now,
                type: .tram
            )

            Task { @MainActor in
                self.bufferMockVehicle(tram4)
            }
        }
        setMockSimulationTimer(timer)
    }
}
