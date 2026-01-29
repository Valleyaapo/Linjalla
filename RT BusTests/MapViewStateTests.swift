//
//  MapViewStateTests.swift
//  RT BusTests
//

import Testing
import RTBusCore
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct MapViewStateTests {

    @Test
    func cameraChangeTogglesStopVisibility() {
        let state = MapViewState()

        state.handleCameraChange(1.0)
        #expect(state.showStops == false)
        #expect(state.showStopNames == false)

        state.handleCameraChange(MapConstants.showStopNamesThreshold * 0.5)
        #expect(state.showStops == true)
        #expect(state.showStopNames == true)
    }
}
