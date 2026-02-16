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
        assertionFailure("Missing DIGITRANSIT_API_KEY in Info.plist")
        return ""
    }()
    
    /// HSL MQTT Username
    static let mqttUsername: String = {
        if let username = Bundle.main.object(forInfoDictionaryKey: "MQTT_USERNAME") as? String,
           !username.isEmpty,
           !username.hasPrefix("$(") {
            return username
        }
        return "digitransit"
    }()
    
    /// HSL MQTT Host
    static let mqttHost: String = {
        if let host = Bundle.main.object(forInfoDictionaryKey: "MQTT_HOST") as? String,
           !host.isEmpty,
           !host.hasPrefix("$(") {
            return host
        }
        return "mqtt.hsl.fi"
    }()
    
    /// HSL MQTT Port
    static let mqttPort: Int = {
        if let portString = Bundle.main.object(forInfoDictionaryKey: "MQTT_PORT") as? String,
           let port = Int(portString) {
            return port
        }
        return 8883
    }()
}
