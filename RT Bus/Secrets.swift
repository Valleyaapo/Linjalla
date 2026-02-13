//
//  Secrets.swift
//  RT Bus
//
//  Created by Assistant on 30.12.2025.
//

import Foundation

enum Secrets {
    /// Digitransit API Key (also used as MQTT Password)
    static let digitransitKey: String = {
        let key = Bundle.main.object(forInfoDictionaryKey: "DIGITRANSIT_API_KEY") as? String
        if let key, !key.isEmpty {
            return key
        }
        fatalError("Missing DIGITRANSIT_API_KEY in Info.plist. check Secrets.xcconfig")
    }()
    
    /// HSL MQTT Username
    static let mqttUsername: String = {
        guard let username = Bundle.main.object(forInfoDictionaryKey: "MQTT_USERNAME") as? String,
              !username.isEmpty else {
            fatalError("Missing MQTT_USERNAME in Info.plist. check Secrets.xcconfig")
        }
        return username
    }()
    
    /// HSL MQTT Host
    static let mqttHost: String = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "MQTT_HOST") as? String,
              !host.isEmpty else {
            fatalError("Missing MQTT_HOST in Info.plist. check Secrets.xcconfig")
        }
        return host
    }()
    
    /// HSL MQTT Port
    static let mqttPort: Int = {
        guard let portString = Bundle.main.object(forInfoDictionaryKey: "MQTT_PORT") as? String,
              let port = Int(portString) else {
            fatalError("Missing or invalid MQTT_PORT in Info.plist. check Secrets.xcconfig")
        }
        return port
    }()
}
