import Foundation

public struct DeparturesRequest: Sendable {
    public let stationId: String
    public let count: Int

    public init(stationId: String, count: Int) {
        self.stationId = stationId
        self.count = count
    }

    public static func stop(stationId: String) -> DeparturesRequest {
        DeparturesRequest(stationId: stationId, count: MapConstants.departuresFetchCount)
    }

    public static func station(stationId: String) -> DeparturesRequest {
        DeparturesRequest(stationId: stationId, count: MapConstants.stationDeparturesFetchCount)
    }
}
