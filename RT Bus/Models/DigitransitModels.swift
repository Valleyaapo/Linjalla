import Foundation

struct GraphQLRouteResponse: Codable, Sendable {
    let data: GraphQLData?
}

struct GraphQLData: Codable, Sendable {
    let routes: [GraphQLRoute]?
}

struct GraphQLRoute: Codable, Sendable {
    let gtfsId: String?
    let shortName: String?
    let longName: String?
}

struct GraphQLStopDeparturesResponse: Codable, Sendable {
    let data: GraphQLStopDeparturesData
}
struct GraphQLStopDeparturesData: Codable, Sendable {
    let stop: GraphQLStation?
}
// Recycling GraphQLStation structure but mapped to 'stop' field now
struct GraphQLStation: Codable, Sendable {
    let stoptimesWithoutPatterns: [GraphQLStoptime]
}
struct GraphQLStoptime: Codable, Sendable {
    let scheduledDeparture: Int
    let realtimeDeparture: Int
    let serviceDay: Int
    let headsign: String?
    let pickupType: String?
    let stop: GraphQLStopShortPlatform?
    let trip: GraphQLTrip?
}
struct GraphQLStopShortPlatform: Codable, Sendable {
    let platformCode: String?
}
struct GraphQLTrip: Codable, Sendable {
    let route: GraphQLRouteShort?
}
struct GraphQLRouteShort: Codable, Sendable {
    let shortName: String?
}

struct GraphQLStopResponse: Codable, Sendable {
    let data: GraphQLStopData
}
struct GraphQLStopData: Codable, Sendable {
    let route: GraphQLRouteWithPatterns?
}
struct GraphQLRouteWithPatterns: Codable, Sendable {
    let patterns: [GraphQLPattern]
}
struct GraphQLPattern: Codable, Sendable {
    let stops: [GraphQLStop]
}
struct GraphQLStop: Codable, Sendable {
    let gtfsId: String
    let name: String
    let lat: Double
    let lon: Double
}
