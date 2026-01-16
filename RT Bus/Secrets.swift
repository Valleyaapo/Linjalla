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
    static let mqttUsername = "digitransit"
    
    /// HSL MQTT Host
    static let mqttHost = "mqtt.hsl.fi"
    
    /// HSL MQTT Port
    static let mqttPort = 8883
}
