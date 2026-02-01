import Foundation

struct RouteStopsVars: Encodable, Sendable {
    let id: String
}

struct EmptyVars: Encodable, Sendable {}

struct SearchRoutesVars: Encodable, Sendable {
    let name: String
    let modes: [String]
}

struct DeparturesVars: Encodable, Sendable {
    let stationId: String
    let count: Int
}
