//
//  VehicleParser.swift
//  RT Bus
//
//  Created by Bolt on 2026-01-01.
//

import Foundation
import OSLog
import RTBusCore

actor VehicleParser {
    private let decoder = JSONDecoder()

    func parse(topic: String, payload: Data, vehicleType: BusModel.VehicleType) -> BusModel? {
        let topicRouteIdIndex = 8
        // Extract routeId from topic (support multiple HFP layouts)
        let parts = topic.split(separator: "/")
        let routeId: String? = parts.count > topicRouteIdIndex ? String(parts[topicRouteIdIndex]) : nil
        let normalizedRouteId = routeId?.replacingOccurrences(of: "HSL:", with: "")

        do {
            let response = try decoder.decode(HSLResponse.self, from: payload)
            return response.VP.toBusModel(routeId: normalizedRouteId, type: vehicleType)
        } catch {
            Logger.busManager.error("VehicleParser: Failed to decode MQTT payload: \(error)")
            return nil
        }
    }
}
