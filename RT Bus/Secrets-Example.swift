//
//  Secrets-Example.swift
//  RT Bus
//
//  Created by Refactor.
//
//  Instructions:
//  1. Duplicate this file and rename it to "Secrets.swift"
//  2. Add your actual Digitransit API key and other credentials.
//  3. Ensure "Secrets.swift" is added to .gitignore (it should be already).
//  4. Remove "Secrets-Example.swift" from your target membership to avoid conflicts.
//

#if false // This prevents compilation - remove this line in your Secrets.swift file

import Foundation

struct Secrets {
    /// The MQTT broker host (e.g., "mqtt.hsl.fi")
    static let mqttHost = "mqtt.hsl.fi"
    
    /// The MQTT broker port (e.g., 8883 for SSL)
    static let mqttPort = 8883
    
    /// The MQTT username (usually empty for HSL open data, or specific if required)
    static let mqttUsername = ""
    
    /// Your Digitransit API Key
    /// Register at https://portal.digitransit.fi/ to get one.
    /// This key is used for both the API requests and as the MQTT password.
    static let digitransitKey = "YOUR_DIGITRANSIT_API_KEY_HERE"
}
#endif // End of conditional compilation

