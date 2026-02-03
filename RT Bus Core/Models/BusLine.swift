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

    // Normalized route ID (cached for performance)
    public let routeId: String

    public init(id: String, shortName: String, longName: String) {
        self.id = id
        self.shortName = shortName
        self.longName = longName

        // Optimize: Calculate once using fast path
        if id.hasPrefix("HSL:") {
            self.routeId = String(id.dropFirst(4))
        } else {
            self.routeId = id
        }
    }

    // MARK: - Codable
    // Custom implementation to exclude `routeId` from encoding/decoding as it is derived.

    enum CodingKeys: String, CodingKey {
        case id, shortName, longName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        self.id = id
        self.shortName = try container.decode(String.self, forKey: .shortName)
        self.longName = try container.decode(String.self, forKey: .longName)

        // Compute derived property
        if id.hasPrefix("HSL:") {
            self.routeId = String(id.dropFirst(4))
        } else {
            self.routeId = id
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(shortName, forKey: .shortName)
        try container.encode(longName, forKey: .longName)
    }
}
