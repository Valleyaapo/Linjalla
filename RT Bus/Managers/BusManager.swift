//
//  BusManager.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import Foundation
import SwiftUI
import Observation
import RTBusCore

@MainActor
@Observable
final class BusManager: BaseVehicleManager {

    // MARK: - Configuration Overrides

    nonisolated override var vehicleType: BusModel.VehicleType { .bus }
    nonisolated override var topicPrefix: String { "bus" }
    nonisolated override var transportMode: TransportMode { .bus }
    nonisolated override var favoritesKey: String { "FavoriteLines" }

    override var defaultFavorites: [BusLine] {
        [
            BusLine(id: "HSL:4600", shortName: "600", longName: "Rautatientori - Lentoasema"),
            BusLine(id: "HSL:2500", shortName: "500", longName: "Munkkivuori - Pasila - Itäkeskus"),
            BusLine(id: "HSL:2510", shortName: "510", longName: "Westendinasema - Meilahti - Herttoniemi")
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
            Task { @MainActor in
                let mockBus = BusModel(
                    id: 9999,
                    lineName: "550",
                    routeId: "HSL:2550",
                    latitude: 60.17 + Double.random(in: -0.01...0.01),
                    longitude: 24.94 + Double.random(in: -0.01...0.01),
                    heading: Int.random(in: 0...360),
                    timestamp: Date().timeIntervalSince1970,
                    type: .bus
                )
                self.vehicleList = [mockBus]
            }
        }
        setMockSimulationTimer(timer)
    }
}
