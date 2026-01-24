import Foundation

nonisolated struct GraphQLRouteResponse: Codable, Sendable {
    let data: GraphQLData?
}

nonisolated struct GraphQLData: Codable, Sendable {
    let routes: [GraphQLRoute]?
}

nonisolated struct GraphQLRoute: Codable, Sendable {
    let gtfsId: String?
    let shortName: String?
    let longName: String?
}

nonisolated struct GraphQLStopDeparturesResponse: Codable, Sendable {
    let data: GraphQLStopDeparturesData
}
nonisolated struct GraphQLStopDeparturesData: Codable, Sendable {
    let stop: GraphQLStation?
}
// Recycling GraphQLStation structure but mapped to 'stop' field now
nonisolated struct GraphQLStation: Codable, Sendable {
    let stoptimesWithoutPatterns: [GraphQLStoptime]
}
nonisolated struct GraphQLStoptime: Codable, Sendable {
    let scheduledDeparture: Int
    let realtimeDeparture: Int
    let serviceDay: Int
    let headsign: String?
    let pickupType: String?
    let stop: GraphQLStopShortPlatform?
    let trip: GraphQLTrip?
}
nonisolated struct GraphQLStopShortPlatform: Codable, Sendable {
    let platformCode: String?
}
nonisolated struct GraphQLTrip: Codable, Sendable {
    let route: GraphQLRouteShort?
}
nonisolated struct GraphQLRouteShort: Codable, Sendable {
    let shortName: String?
}

nonisolated struct GraphQLStopResponse: Codable, Sendable {
    let data: GraphQLStopData
}
nonisolated struct GraphQLStopData: Codable, Sendable {
    let route: GraphQLRouteWithPatterns?
}
nonisolated struct GraphQLRouteWithPatterns: Codable, Sendable {
    let patterns: [GraphQLPattern]
}
nonisolated struct GraphQLPattern: Codable, Sendable {
    let stops: [GraphQLStop]
}
nonisolated struct GraphQLStop: Codable, Sendable {
    let gtfsId: String
    let name: String
    let lat: Double
    let lon: Double
}
