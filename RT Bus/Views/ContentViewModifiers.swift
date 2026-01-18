//
//  ContentViewModifiers.swift
//  RT Bus
//
//  ViewModifiers used by ContentView to reduce expression complexity
//

import SwiftUI

// MARK: - Tasks and Change Handlers Modifier

struct TasksAndChangeModifiers: ViewModifier {
    let startupTask: @MainActor @Sendable () async -> Void
    let busVehicleList: [BusModel]
    let tramVehicleList: [BusModel]
    let busFavoriteLines: [BusLine]
    let tramFavoriteLines: [BusLine]
    let busListChanged: (([BusModel], [BusModel]) -> Void)?
    let tramListChanged: (([BusModel], [BusModel]) -> Void)?
    let busFavoritesChanged: (([BusLine], [BusLine]) -> Void)?
    let tramFavoritesChanged: (([BusLine], [BusLine]) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .task {
                await startupTask()
            }
            .onChange(of: busVehicleList, busListChanged ?? { _, _ in })
            .onChange(of: tramVehicleList, tramListChanged ?? { _, _ in })
            .onChange(of: busFavoriteLines, busFavoritesChanged ?? { _, _ in })
            .onChange(of: tramFavoriteLines, tramFavoritesChanged ?? { _, _ in })
    }
}

// MARK: - Alerts Modifier

struct AlertsModifier: ViewModifier {
    let busErrorBinding: Binding<Bool>
    let tramErrorBinding: Binding<Bool>
    let stopErrorBinding: Binding<Bool>
    @Binding var isHSLErrorPresented: Bool
    
    let busErrorActions: () -> AnyView
    let tramErrorActions: () -> AnyView
    let stopErrorActions: () -> AnyView
    let hslErrorActions: () -> AnyView
    
    let busErrorMessage: () -> AnyView
    let tramErrorMessage: () -> AnyView
    let stopErrorMessage: () -> AnyView
    let hslErrorMessage: () -> AnyView
    
    func body(content: Content) -> some View {
        content
            .alert("ui.alert.busError", isPresented: busErrorBinding, actions: busErrorActions, message: busErrorMessage)
            .alert("ui.alert.tramError", isPresented: tramErrorBinding, actions: tramErrorActions, message: tramErrorMessage)
            .alert("ui.alert.stopError", isPresented: stopErrorBinding, actions: stopErrorActions, message: stopErrorMessage)
            .alert("ui.alert.hslAppMissing", isPresented: $isHSLErrorPresented, actions: hslErrorActions, message: hslErrorMessage)
    }
}
