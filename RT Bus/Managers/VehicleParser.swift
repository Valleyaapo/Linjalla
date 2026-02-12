//
//  VehicleParser.swift
//  RT Bus
//
//  Created by Bolt on 2025-05-23.
//

import Foundation
import OSLog
import RTBusCore

actor VehicleParser {
    private let decoder = JSONDecoder()

    func parse(topicName: String, payload: Data, vehicleType: BusModel.VehicleType) -> BusModel? {
        let topicRouteIdIndex = 8

        // Extract routeId from topic (support multiple HFP layouts)
        let parts = topicName.split(separator: "/")
        let routeId: String? = parts.count > topicRouteIdIndex ? String(parts[topicRouteIdIndex]) : nil

        do {
            let response = try decoder.decode(HSLResponse.self, from: payload)
            let vp = response.VP

            guard let lat = vp.lat, let long = vp.long, let desi = vp.desi else { return nil }

            // Note: routeId is normalized in BusModel.init
            return BusModel(
                id: vp.veh,
                lineName: desi,
                routeId: routeId,
                latitude: lat,
                longitude: long,
                heading: vp.hdg,
                timestamp: vp.tsi ?? Date().timeIntervalSince1970,
                type: vehicleType
            )
        } catch {
            Logger.busManager.error("VehicleParser: Failed to decode MQTT payload: \(error)")
            return nil
        }
    }
}
