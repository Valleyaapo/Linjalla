import Foundation

struct RouteStopsVars: Encodable, Sendable {
    let id: String
}

struct SearchRoutesVars: Encodable, Sendable {
    let name: String
}

struct DeparturesVars: Encodable, Sendable {
    let stationId: String
    let count: Int
}
