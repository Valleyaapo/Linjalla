//
//  SelectionStoreTests.swift
//  RTBusTests
//
//  Created by Assistant on 16.01.2026.
//

import Testing
import Foundation
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct SelectionStoreTests {
    @Test
    func persistsSelectedLines() async {
        let suiteName = "SelectionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            { "data": { "route": { "patterns": [] } } }
            """.data(using: .utf8)
            return (response, data)
        }

        let busManager = BusManager(urlSession: session, connectOnStart: false)
        let tramManager = TramManager(urlSession: session, connectOnStart: false)
        let stopManager = StopManager(urlSession: session)

        let store = SelectionStore(
            busManager: busManager,
            tramManager: tramManager,
            stopManager: stopManager,
            userDefaults: defaults
        )

        let line = BusLine(id: "HSL:1234", shortName: "1234", longName: "Test Line")
        store.toggleSelection(for: line)

        let reloadedStore = SelectionStore(
            busManager: busManager,
            tramManager: tramManager,
            stopManager: stopManager,
            userDefaults: defaults
        )
        reloadedStore.loadSelectedLines()

        #expect(reloadedStore.selectedLines.contains(line))
    }
}
