//
//  VehicleParser.swift
//  RT Bus
//
//  Created by Bolt on 15.05.2025.
//

import Foundation
import OSLog
import RTBusCore

/// Offloads high-frequency MQTT message parsing to a private actor, preventing Main Actor blocking during JSON decoding.
actor VehicleParser {

    // Shared decoder for this actor to reduce allocation overhead
    private let decoder = JSONDecoder()

    /// Parses a raw MQTT payload into a BusModel.
    /// - Parameters:
    ///   - topicName: The MQTT topic name (e.g., "/hfp/v2/journey/ongoing/vp/bus/HSL/1/10/1001/1")
    ///   - payload: The raw JSON data
    ///   - type: The vehicle type (bus or tram)
    /// - Returns: A `BusModel` if parsing succeeds, otherwise `nil`.
    func parse(topicName: String, payload: Data, type: BusModel.VehicleType) -> BusModel? {
        let topicRouteIdIndex = 8

        // Extract routeId from topic
        let parts = topicName.split(separator: "/")
        let routeId: String? = parts.count > topicRouteIdIndex ? String(parts[topicRouteIdIndex]) : nil
        let normalizedRouteId = routeId?.replacingOccurrences(of: "HSL:", with: "")

        do {
            let response = try decoder.decode(HSLResponse.self, from: payload)
            // Use the toBusModel method from VehiclePosition which handles coordinate validation
            return response.VP.toBusModel(routeId: normalizedRouteId, type: type)
        } catch {
            Logger.busManager.error("VehicleParser: Failed to decode MQTT payload: \(error)")
            return nil
        }
    }
}
