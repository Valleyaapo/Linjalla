//
//  BusLine.swift
//  RT Bus
//
//  Created by Refactor on 01.01.2026.
//

import Foundation

public struct BusLine: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let shortName: String
    public let longName: String

    public init(id: String, shortName: String, longName: String) {
        self.id = id
        self.shortName = shortName
        self.longName = longName
    }

    public var routeId: String { id.replacingOccurrences(of: "HSL:", with: "") }
}
