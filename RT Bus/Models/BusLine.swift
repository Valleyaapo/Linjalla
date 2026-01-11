//
//  BusLine.swift
//  RT Bus
//
//  Created by Refactor on 01.01.2026.
//

import Foundation

struct BusLine: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let shortName: String
    let longName: String
    
    var routeId: String { id.replacingOccurrences(of: "HSL:", with: "") }
}

struct GraphQLRouteResponse: Codable, Sendable {
    let data: GraphQLData
}

struct GraphQLData: Codable, Sendable {
    let routes: [GraphQLRoute]
}

struct GraphQLRoute: Codable, Sendable {
    let gtfsId: String?
    let shortName: String?
    let longName: String?
}
