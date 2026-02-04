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
    public let routeId: String

    public init(id: String, shortName: String, longName: String) {
        self.id = id
        self.shortName = shortName
        self.longName = longName
        self.routeId = id.replacingOccurrences(of: "HSL:", with: "")
    }

    enum CodingKeys: String, CodingKey {
        case id, shortName, longName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.shortName = try container.decode(String.self, forKey: .shortName)
        self.longName = try container.decode(String.self, forKey: .longName)
        self.routeId = self.id.replacingOccurrences(of: "HSL:", with: "")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(shortName, forKey: .shortName)
        try container.encode(longName, forKey: .longName)
    }
}
