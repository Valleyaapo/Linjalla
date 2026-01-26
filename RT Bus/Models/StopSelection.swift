//
//  StopSelection.swift
//  RT Bus
//
//  Created by Codex on 22.01.2026.
//

import Foundation

struct StopSelection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let stops: [BusStop]
}
