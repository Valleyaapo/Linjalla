//
//  VehicleParser.swift
//  RT Bus
//
//  Created by Bolt on 2025-05-20.
//

import Foundation
import OSLog
import RTBusCore

actor VehicleParser {
    private let decoder = JSONDecoder()
    private let topicRouteIdIndex = 8

    func parse(topicName: String, payload: Data, vehicleType: BusModel.VehicleType) -> BusModel? {
        // Extract routeId from topic (support multiple HFP layouts)
        let parts = topicName.split(separator: "/")
        let routeId: String? = parts.count > topicRouteIdIndex ? String(parts[topicRouteIdIndex]) : nil
        let normalizedRouteId = routeId?.replacingOccurrences(of: "HSL:", with: "")

        do {
            let response = try decoder.decode(HSLResponse.self, from: payload)
            let vp = response.VP

            return vp.toBusModel(
                routeId: normalizedRouteId,
                type: vehicleType
            )
        } catch {
            Logger.busManager.error("VehicleParser: Failed to decode MQTT payload: \(error)")
            return nil
        }
    }
}
