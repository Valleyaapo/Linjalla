//
//  RT_BusApp.swift
//  RT Bus
//
//  Created by Aapo Laakso on 28.12.2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct RT_BusApp: App {
    @State private var busManager: BusManager
    @State private var tramManager: TramManager
    @State private var selectionStore: SelectionStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if ProcessInfo.processInfo.arguments.contains("UITesting") {
            #if canImport(UIKit)
            UIView.setAnimationsEnabled(false)
            #endif
        }
        UITestNetworkStub.registerIfNeeded()
        let session: URLSession
        if ProcessInfo.processInfo.arguments.contains("UITesting") {
            session = UITestNetworkStub.makeSession()
        } else {
            session = .shared
        }

        let busManager = BusManager(urlSession: session)
        let tramManager = TramManager(urlSession: session)
        let stopManager = StopManager(urlSession: session)
        _busManager = State(initialValue: busManager)
        _tramManager = State(initialValue: tramManager)
        _selectionStore = State(initialValue: SelectionStore(busManager: busManager, tramManager: tramManager, stopManager: stopManager))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(busManager)
                .environment(tramManager)
                .environment(selectionStore)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                busManager.disconnect()
                tramManager.disconnect()
                selectionStore.cancelPendingUpdate()
            case .active:
                busManager.reconnect()
                tramManager.reconnect()
            default:
                break
            }
        }
    }
}
