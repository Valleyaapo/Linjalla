//
//  MapViewState.swift
//  RT Bus
//
//  Created by Codex on 26.01.2026.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class MapViewState: Sendable {
    var showStops = true
    var showStopNames = false
    var selectedStop: StopSelection?

    func handleCameraChange(_ zoomLevel: Double) {
        let shouldShowStops = zoomLevel < MapConstants.showStopsThreshold
        let shouldShowStopNames = zoomLevel < MapConstants.showStopNamesThreshold

        if showStops != shouldShowStops {
            withAnimation(.easeInOut(duration: 0.3)) {
                showStops = shouldShowStops
            }
        }
        if showStopNames != shouldShowStopNames {
            withAnimation(.easeInOut(duration: 0.2)) {
                showStopNames = shouldShowStopNames
            }
        }
    }

    func handleStopTapped(_ selection: StopSelection) {
        selectedStop = selection
    }
}
