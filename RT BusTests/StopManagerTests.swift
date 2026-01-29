//
//  StopManagerTests.swift
//  RTBusTests
//
//  Created by Automation on 01.01.2026.
//

import Testing
import Foundation
import RTBusCore
@testable import RT_Bus

@MainActor
@Suite(.serialized)
struct StopManagerTests {

    final class StopManagerTestURLProtocol: URLProtocol {
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
    func fetchDepartures() async throws {
        // Setup
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StopManagerTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let stopManager = StopManager(urlSession: session)
        
        let now = Int(Date().timeIntervalSince1970)
        let serviceDay = now - (now % 86_400)
        let realtimeDeparture = (now - serviceDay) + 300

        StopManagerTestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "stop": {
                  "stoptimesWithoutPatterns": [
                    {
                      "scheduledDeparture": \(realtimeDeparture),
                      "realtimeDeparture": \(realtimeDeparture),
                      "serviceDay": \(serviceDay),
                      "headsign": "Destination",
                      "pickupType": "SCHEDULED",
                      "stop": { "platformCode": "1" },
                      "trip": { "route": { "shortName": "550" } }
                    }
                  ]
                }
             }
            }
            """.data(using: .utf8)
            return (response, data)
        }
        
        let departures = try await stopManager.fetchDepartures(for: "HSL:TEST")
        #expect(departures.count == 1)
        #expect(departures.first?.lineName == "550")
        #expect(departures.first?.platform == "1")
    }
    
    @Test
    func fetchDeparturesEmpty() async throws {
         // Setup
         let configuration = URLSessionConfiguration.ephemeral
         configuration.protocolClasses = [StopManagerTestURLProtocol.self]
         let session = URLSession(configuration: configuration)
         let stopManager = StopManager(urlSession: session)

         StopManagerTestURLProtocol.requestHandler = { request in
             let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
             let data = """
             { "data": { "stop": { "stoptimesWithoutPatterns": [] } } }
             """.data(using: .utf8)
             return (response, data)
         }
         
         let departures = try await stopManager.fetchDepartures(for: "HSL:TEST")
        #expect(departures.isEmpty)
     }

    @Test
    func updateStopsRemovesDeselectedLines() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StopManagerTestURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let stopManager = StopManager(urlSession: session)

        let lineA = BusLine(id: "HSL:LINEA", shortName: "A", longName: "Line A")
        let lineB = BusLine(id: "HSL:LINEB", shortName: "B", longName: "Line B")

        var requestedLineIds: [String] = []
        var requestCount = 0
        StopManagerTestURLProtocol.requestHandler = { request in
            requestCount += 1
            let lineId = extractVariable(name: "id", from: request) ?? (requestCount == 1 ? "HSL:LINEA" : "HSL:LINEB")
            requestedLineIds.append(lineId)
            let stopId = requestCount == 1 ? "HSL:STOPA" : "HSL:STOPB"

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = """
            {
              "data": {
                "route": {
                  "patterns": [
                    {
                      "stops": [
                        { "gtfsId": "\(stopId)", "name": "Stop", "lat": 60.1, "lon": 24.9 }
                      ]
                    }
                  ]
                }
              }
            }
            """.data(using: .utf8)
            return (response, data)
        }

        stopManager.updateStops(for: [lineA])
        try await waitUntil {
            stopManager.allStops.count == 1
        }
        #expect(stopManager.allStops.first?.id == "HSL:STOPA")

        stopManager.updateStops(for: [lineA, lineB])
        try await waitUntil {
            stopManager.allStops.count == 2
        }
        #expect(stopManager.allStops.count == 2)

        stopManager.updateStops(for: [lineA])
        try await waitUntil {
            stopManager.allStops.count == 1
        }
        #expect(stopManager.allStops.count == 1)
        #expect(stopManager.allStops.first?.id == "HSL:STOPA")
        #expect(requestedLineIds.contains("HSL:LINEA"))
        #expect(requestedLineIds.contains("HSL:LINEB"))
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: @escaping () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("Condition not met before timeout")
    }

    private func extractVariable(name: String, from request: URLRequest) -> String? {
        guard let data = try? requestBodyData(request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let variables = json["variables"] as? [String: Any],
              let value = variables[name] as? String else {
            return nil
        }
        return value
    }
}
