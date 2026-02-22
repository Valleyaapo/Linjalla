import Foundation
import CoreLocation
import OSLog
import RTBusCore

actor VehicleParser {
    private let decoder = JSONDecoder()

    func parse(topicName: String, payload: Data, vehicleType: BusModel.VehicleType) -> BusModel? {
        let topicRouteIdIndex = 8

        // Extract routeId from topic (support multiple HFP layouts)
        let parts = topicName.split(separator: "/")
        let routeId: String? = parts.count > topicRouteIdIndex ? String(parts[topicRouteIdIndex]) : nil
        let normalizedRouteId = routeId?.replacingOccurrences(of: "HSL:", with: "")

        do {
            let response = try decoder.decode(HSLResponse.self, from: payload)
            // Use the helper method on VehiclePosition to convert to BusModel
            return response.VP.toBusModel(routeId: normalizedRouteId, type: vehicleType)
        } catch {
            Logger.busManager.error("VehicleParser: Failed to decode MQTT payload: \(error)")
            return nil
        }
    }
}
