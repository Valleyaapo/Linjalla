//
//  ContentView+Alerts.swift
//  RT Bus
//
//  Alert bindings and views for ContentView
//

import SwiftUI

extension ContentView {
    
    // MARK: - Alert Bindings
    
    var busErrorBinding: Binding<Bool> {
        Binding(
            get: { busManager.error != nil },
            set: { if !$0 { busManager.error = nil } }
        )
    }
    
    var tramErrorBinding: Binding<Bool> {
        Binding(
            get: { tramManager.error != nil },
            set: { if !$0 { tramManager.error = nil } }
        )
    }
    
    var stopErrorBinding: Binding<Bool> {
        Binding(
            get: { stopManager.error != nil },
            set: { if !$0 { stopManager.error = nil } }
        )
    }
    
    // MARK: - Alert Actions
    
    func busErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) { busManager.error = nil })
    }
    
    func tramErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) { tramManager.error = nil })
    }
    
    func stopErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) { stopManager.error = nil })
    }
    
    func hslErrorActions() -> AnyView {
        AnyView(Button("ui.button.ok", role: .cancel) {})
    }
    
    // MARK: - Alert Messages
    
    func busErrorMessage() -> AnyView {
        AnyView(Text(busManager.error?.localizedDescription ?? ""))
    }
    
    func tramErrorMessage() -> AnyView {
        AnyView(Text(tramManager.error?.localizedDescription ?? ""))
    }
    
    func stopErrorMessage() -> AnyView {
        AnyView(Text(stopManager.error?.localizedDescription ?? ""))
    }
    
    func hslErrorMessage() -> AnyView {
        AnyView(Text("ui.error.hslNotInstalled"))
    }
}
