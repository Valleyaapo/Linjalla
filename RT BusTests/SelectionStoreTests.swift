//
//  SelectionStoreTests.swift
//  RTBusTests
//
//  Created by Assistant on 16.01.2026.
//

import Testing
import Foundation
import RTBusCore
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct SelectionStoreTests {
    final class SelectionStoreTestURLProtocol: URLProtocol {
        nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

        override class func canInit(with request: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                fatalError("Handler is unavailable.")
            }

            do {
                let (response, data) = try handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                if let data {
                    client?.urlProtocol(self, didLoad: data)
                }
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    @Test
    func persistsSelectedLines() async {
        let suiteName = "SelectionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SelectionStoreTestURLProtocol.self]
        let session = URLSession(configuration: configuration)

        SelectionStoreTestURLProtocol.requestHandler = { request in
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

    @Test
    func loadsDefaultFavoritesWhenNoSelectionSaved() {
        let suiteName = "SelectionStoreTests.Defaults.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SelectionStoreTestURLProtocol.self]
        let session = URLSession(configuration: configuration)

        SelectionStoreTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            { "data": { "route": { "patterns": [] } } }
            """.data(using: .utf8)
            return (response, data)
        }

        let busManager = BusManager(urlSession: session, connectOnStart: false)
        let tramManager = TramManager(urlSession: session, connectOnStart: false)
        let stopManager = StopManager(urlSession: session)

        let busLine = BusLine(id: "HSL:1001", shortName: "1", longName: "Bus 1")
        let tramLine = BusLine(id: "HSL:1004", shortName: "4", longName: "Tram 4")
        busManager.favoriteLines = [busLine]
        tramManager.favoriteLines = [tramLine]

        let store = SelectionStore(
            busManager: busManager,
            tramManager: tramManager,
            stopManager: stopManager,
            userDefaults: defaults
        )
        store.loadSelectedLines()

        #expect(store.selectedLines.contains(busLine))
        #expect(store.selectedLines.contains(tramLine))
        #expect(store.selectedLines.count == 2)
    }
}
