//
//  RT_BusApp.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import SwiftUI

@main
struct RT_BusApp: App {
    @State private var busManager = BusManager()
    @State private var tramManager = TramManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView(busManager: busManager, tramManager: tramManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                busManager.disconnect()
                tramManager.disconnect()
            case .active:
                busManager.reconnect()
                tramManager.reconnect()
            default:
                break
            }
        }
    }
}
