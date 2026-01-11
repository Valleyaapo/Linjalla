//
//  AppError.swift
//  RT Bus
//
//  Created by Automation on 01.01.2026.
//

import Foundation
import OSLog

enum AppError: LocalizedError, Equatable {
    case networkError(String)
    case apiError(String)
    case decodingError(String)
    case locationError(String)
    case mqttError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return String(format: NSLocalizedString("error.network", comment: ""), msg)
        case .apiError(let msg): return String(format: NSLocalizedString("error.api", comment: ""), msg)
        case .decodingError(let msg): return String(format: NSLocalizedString("error.decoding", comment: ""), msg)
        case .locationError(let msg): return String(format: NSLocalizedString("error.location", comment: ""), msg)
        case .mqttError(let msg): return String(format: NSLocalizedString("error.mqtt", comment: ""), msg)
        case .unknown(let msg): return String(format: NSLocalizedString("error.unknown", comment: ""), msg)
        }
    }
}

extension Logger {
    private static let subsystem = "com.aapolaakso.RT-Bus"
    
    nonisolated static let network = Logger(subsystem: subsystem, category: "Network")
    nonisolated static let busManager = Logger(subsystem: subsystem, category: "BusManager")
    nonisolated static let stopManager = Logger(subsystem: subsystem, category: "StopManager")
    nonisolated static let ui = Logger(subsystem: subsystem, category: "UI")
}
