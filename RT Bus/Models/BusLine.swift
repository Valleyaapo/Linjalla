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
