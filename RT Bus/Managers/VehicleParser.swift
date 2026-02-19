//
//  VehicleParser.swift
//  RT Bus
//
//  Created by Bolt on 2025-05-15.
//

import Foundation
import OSLog
import RTBusCore

actor VehicleParser {
    private let decoder = JSONDecoder()

    func parse(payload: Data, topic: String, vehicleType: BusModel.VehicleType) -> BusModel? {
        let topicRouteIdIndex = 8

        // Extract routeId from topic (support multiple HFP layouts)
        let parts = topic.split(separator: "/")
        let routeId: String? = parts.count > topicRouteIdIndex ? String(parts[topicRouteIdIndex]) : nil
        let normalizedRouteId = routeId?.replacingOccurrences(of: "HSL:", with: "")

        do {
            let response = try decoder.decode(HSLResponse.self, from: payload)
            // Use the convenience method on VehiclePosition to convert to BusModel
            return response.VP.toBusModel(routeId: normalizedRouteId, type: vehicleType)
        } catch {
            Logger(subsystem: "com.rtbus", category: "VehicleParser").error("Failed to decode MQTT payload: \(error)")
            return nil
        }
    }
}
