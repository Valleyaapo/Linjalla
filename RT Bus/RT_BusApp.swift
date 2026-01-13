//
//  RT_BusApp.swift
//  RT Bus
//
//  Updated on 13.01.2026.
//

import SwiftUI

@main
struct RT_BusApp: App {
    @State private var busManager = BusManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(busManager: busManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                busManager.disconnect()
            case .active:
                busManager.reconnect()
            default:
                break
            }
        }
    }
}
